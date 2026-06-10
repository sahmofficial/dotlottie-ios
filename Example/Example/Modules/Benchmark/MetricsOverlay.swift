//
//  MetricsOverlay.swift
//  DotLottieIosTestApp
//
//  Shared UI for the renderer benchmarks: a renderer toggle and a live metrics HUD.
//

import SwiftUI

/// Which renderer a benchmark screen is currently exercising.
enum Renderer: String, CaseIterable, Identifiable {
    case cpu = "CPU"
    case webGPU = "WebGPU"

    var id: String { rawValue }
}

/// Segmented control to switch the screen between the CPU and WebGPU renderers.
struct RendererPicker: View {
    @Binding var selection: Renderer

    var body: some View {
        Picker("Renderer", selection: $selection) {
            ForEach(Renderer.allCases) { renderer in
                Text(renderer.rawValue).tag(renderer)
            }
        }
        .pickerStyle(.segmented)
    }
}

/// Compact heads-up display of the live renderer metrics.
struct MetricsOverlay: View {
    @ObservedObject var monitor: PerformanceMonitor

    var body: some View {
        HStack(spacing: 14) {
            metric("CPU", String(format: "%.0f%%", monitor.cpuPercent))
            divider
            metric("MEM", String(format: "%.0f MB", monitor.memoryMB))
            divider
            metric("FRAME", String(format: "%.1f ms", monitor.renderMs))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.1))
            .frame(width: 1, height: 22)
    }

    private func metric(_ label: String, _ value: String, color: Color = .primary) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.subheadline, design: .monospaced))
                .fontWeight(.semibold)
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.secondary)
        }
    }
}
