//
//  PerformanceMonitor.swift
//  DotLottieIosTestApp
//
//  Live performance sampling for the renderer benchmarks.
//
//  FPS and per-frame render time are sourced from `DotLottieRenderProbe`, which both the CPU
//  (`Coordinator`) and WebGPU (`DotLottieWebGPUView`) render loops feed once per rendered
//  frame. CPU % and memory are sampled from the mach task once per second.
//

import Foundation
import SwiftUI
import DotLottie

#if canImport(Darwin)
import Darwin
#endif

/// Samples and publishes live performance metrics while a benchmark screen is on-screen.
///
/// Call ``start()`` in `onAppear` and ``stop()`` in `onDisappear`. `start()` installs the
/// shared `DotLottieRenderProbe` callback; `stop()` removes it so there is zero overhead once
/// the screen is dismissed.
final class PerformanceMonitor: ObservableObject {

    @Published var renderMs: Double = 0
    @Published var cpuPercent: Double = 0
    @Published var memoryMB: Double = 0

    /// Frames counted since the last 1s tick, used only to average render time
    /// (written on the render/main thread).
    private var frameCount: Int = 0
    /// Sum of per-frame render durations (ms) since the last 1s tick.
    private var renderSum: Double = 0

    private var timer: Timer?

    func start() {
        guard timer == nil else { return }

        frameCount = 0
        renderSum = 0

        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.sample()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func sample() {
        let frames = frameCount
        let renderTotal = renderSum
        frameCount = 0
        renderSum = 0

        let renderMs = frames > 0 ? renderTotal / Double(frames) : 0
        let cpu = Self.cpuUsagePercent()
        let mem = Self.memoryFootprintMB()

        // Already on the main RunLoop, but keep the publish explicit.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.renderMs = renderMs
            self.cpuPercent = cpu
            self.memoryMB = mem
        }
    }

    deinit { stop() }

    // MARK: - mach sampling

    /// Total process CPU usage across all threads, as a percentage (can exceed 100% on
    /// multi-core when several threads are busy).
    private static func cpuUsagePercent() -> Double {
        var threadList: thread_act_array_t?
        var threadCount: mach_msg_type_number_t = 0
        guard task_threads(mach_task_self_, &threadList, &threadCount) == KERN_SUCCESS,
              let threads = threadList else { return 0 }

        defer {
            let size = vm_size_t(Int(threadCount) * MemoryLayout<thread_t>.stride)
            vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: threads)), size)
        }

        var total: Double = 0
        for i in 0..<Int(threadCount) {
            var info = thread_basic_info()
            var count = mach_msg_type_number_t(MemoryLayout<thread_basic_info_data_t>.size / MemoryLayout<integer_t>.size)
            let kr = withUnsafeMutablePointer(to: &info) {
                $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                    thread_info(threads[i], thread_flavor_t(THREAD_BASIC_INFO), $0, &count)
                }
            }
            if kr == KERN_SUCCESS, (info.flags & TH_FLAGS_IDLE) == 0 {
                total += Double(info.cpu_usage) / Double(TH_USAGE_SCALE) * 100.0
            }
        }
        return total
    }

    /// Resident memory footprint (phys_footprint) in megabytes.
    private static func memoryFootprintMB() -> Double {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let kr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        guard kr == KERN_SUCCESS else { return 0 }
        return Double(info.phys_footprint) / (1024 * 1024)
    }
}
