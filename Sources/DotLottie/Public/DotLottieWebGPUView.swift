#if os(iOS) || os(macOS)

#if os(iOS)
import UIKit
import QuartzCore
import DotLottiePlayer
public typealias PlatformBase = UIView
#elseif os(macOS)
import AppKit
import QuartzCore
import DotLottiePlayer
public typealias PlatformBase = NSView
#endif

/// A UIView/NSView that renders a Lottie animation via WebGPU (Metal backend).
///
/// Pixels are written directly to a Metal surface — the CPU pixel buffer and
/// CGImage conversion used by the software-rendering path are bypassed entirely.
///
/// Basic usage:
/// ```swift
/// let view = DotLottieWebGPUView(config: Config(autoplay: true, loopAnimation: true))
/// view.loadAnimation(fileName: "my_animation")
/// ```
public class DotLottieWebGPUView: PlatformBase {

    // MARK: - Private state

    private let bridge: DotLottiePlayer

    /// Opaque pointer to the native WgpuContext (instance/adapter/device/queue/surface).
    private var wgpuContext: UnsafeMutableRawPointer?

    /// Cached raw wgpu pointers — held so resize doesn't recreate the whole context.
    private var wgpuPointers: (device: UInt64, instance: UInt64, surface: UInt64)?

    /// The physical drawable size that was last passed to `setWebGPUTarget`.
    private var configuredSize: CGSize = .zero

    /// Timestamp of the previous tick (seconds), used to compute dt.
    private var lastTickTime: CFTimeInterval = 0

    /// Animation load deferred until the WebGPU canvas exists.
    /// ThorVG requires set_wg_target to be called before loading animation data
    /// so the canvas exists when the animation paint is added.
    private var pendingLoad: (() -> Bool)?

    // MARK: - Platform-specific display link

#if os(iOS)
    private var displayLink: CADisplayLink?
#elseif os(macOS)
    private var displayTimer: DispatchSourceTimer?
#endif

    // MARK: - Metal layer accessor

    private var metalLayer: CAMetalLayer {
#if os(iOS)
        return layer as! CAMetalLayer
#elseif os(macOS)
        return layer as! CAMetalLayer
#endif
    }

    // MARK: - Display scale

    private var displayScale: CGFloat {
#if os(iOS)
        return UIScreen.main.scale
#elseif os(macOS)
        return window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 1.0
#endif
    }

    // MARK: - Init

    public init(config: Config = Config()) {
        bridge = DotLottiePlayer(config: config)
        super.init(frame: .zero)
        setupMetalLayer()
        startDisplayLink()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    // MARK: - Layer setup

    /// On iOS the backing layer is overridden to CAMetalLayer via layerClass.
    /// On macOS we assign it explicitly.
#if os(iOS)
    override public class var layerClass: AnyClass { CAMetalLayer.self }

    private func setupMetalLayer() {
        let ml = metalLayer
        ml.pixelFormat = .bgra8Unorm
        ml.framebufferOnly = false
        ml.isOpaque = false
    }
#elseif os(macOS)
    private func setupMetalLayer() {
        wantsLayer = true
        let ml = CAMetalLayer()
        ml.pixelFormat = .bgra8Unorm
        ml.framebufferOnly = false
        ml.isOpaque = false
        // ThorVG's wg renderer always requests WGPUPresentMode_Immediate on Apple targets.
        ml.displaySyncEnabled = false
        layer = ml
    }
#endif

    // MARK: - Layout → WebGPU reconfiguration

#if os(iOS)
    override public func layoutSubviews() {
        super.layoutSubviews()
        reconfigureWebGPUIfNeeded()
    }
#elseif os(macOS)
    override public func layout() {
        super.layout()
        reconfigureWebGPUIfNeeded()
    }
#endif

    private func reconfigureWebGPUIfNeeded() {
        let scale = displayScale
        let physical = CGSize(width: bounds.width * scale, height: bounds.height * scale)
        guard physical.width > 0, physical.height > 0 else { return }

        let w = UInt32(physical.width)
        let h = UInt32(physical.height)

        if wgpuContext == nil {
            // First layout: create the wgpu context from the CAMetalLayer.
            // MUST be on the main thread (Metal requirement).
            let layerPtr = Unmanaged.passUnretained(metalLayer).toOpaque()
            guard let ctx = DotLottiePlayer.createWebGPUContext(metalLayer: layerPtr) else {
                print("[DotLottieWebGPUView] Failed to create WebGPU context")
                return
            }
            guard let ptrs = DotLottiePlayer.getWebGPUPointers(context: ctx) else {
                DotLottiePlayer.freeWebGPUContext(context: ctx)
                return
            }
            wgpuContext = ctx
            wgpuPointers = ptrs
            metalLayer.drawableSize = physical
            configuredSize = physical
        } else if physical != configuredSize {
            // Resize: update drawable size; reconfigure ThorVG's wg canvas below.
            metalLayer.drawableSize = physical
            configuredSize = physical
        } else {
            return
        }

        guard let ptrs = wgpuPointers else { return }
        let device   = UnsafeMutableRawPointer(bitPattern: UInt(ptrs.device))
        let instance = UnsafeMutableRawPointer(bitPattern: UInt(ptrs.instance))
        let surface  = UnsafeMutableRawPointer(bitPattern: UInt(ptrs.surface))

        _ = bridge.setWebGPUTarget(
            device: device,
            instance: instance,
            target: surface,
            width: w,
            height: h
        )

        // Run any animation load that was deferred waiting for the canvas.
        if let load = pendingLoad {
            pendingLoad = nil
            _ = load()
        }
    }

    // MARK: - Render loop

#if os(iOS)
    private func startDisplayLink() {
        displayLink = CADisplayLink(target: self, selector: #selector(onDisplayLink))
        displayLink?.add(to: .main, forMode: .common)
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func onDisplayLink(_ link: CADisplayLink) {
        performTick()
    }

#elseif os(macOS)
    private func startDisplayLink() {
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: 1.0 / 60.0, leeway: .milliseconds(2))
        timer.setEventHandler { [weak self] in self?.performTick() }
        timer.resume()
        displayTimer = timer
    }

    private func stopDisplayLink() {
        displayTimer?.cancel()
        displayTimer = nil
    }
#endif

    private func performTick() {
        guard wgpuContext != nil else { return }
        let now = CACurrentMediaTime()
        let dt = lastTickTime == 0 ? 0.0 : Float((now - lastTickTime) * 1000.0)
        lastTickTime = now

        // Wrap render+present in an explicit autorelease pool so that wgpu-native's
        // "(wgpu internal) Signal" MTLCommandBuffers — created by every wgpuQueueSubmit
        // for GPU completion tracking — are released before the next frame's submit
        // tries to recycle their associated Staging buffers.  Without this, Metal
        // Debug fires -[MTLDebugDevice notifyExternalReferencesNonZeroOnDealloc:]
        // because the Signal ObjC object (in the run-loop pool) still holds a Metal
        // retain on the Staging buffer when wgpu recycles it.
        autoreleasepool {
            if bridge.tick(dt: dt) {
                if let ctx = wgpuContext {
                    DotLottiePlayer.presentWebGPUSurface(context: ctx)
                }
            }
        }
    }

    // MARK: - Public API

    /// Load a .json or .lottie file from the given bundle.
    /// If the WebGPU canvas is not yet ready (no layout pass), loading is deferred
    /// until the canvas exists. The WebGPU canvas must exist before animation data
    /// is added (ThorVG requirement: set_wg_target before load).
    @discardableResult
    public func loadAnimation(fileName: String, bundle: Bundle = .main) -> Bool {
        reconfigureWebGPUIfNeeded()
        if wgpuContext != nil {
            return loadAnimationImmediate(fileName: fileName, bundle: bundle)
        }
        pendingLoad = { [weak self] in
            self?.loadAnimationImmediate(fileName: fileName, bundle: bundle) ?? false
        }
        return true
    }

    private func loadAnimationImmediate(fileName: String, bundle: Bundle) -> Bool {
        if let url = bundle.url(forResource: fileName, withExtension: "json"),
           let data = try? String(contentsOf: url) {
            return bridge.loadAnimationData(animationData: data)
        }
        if let url = bundle.url(forResource: fileName, withExtension: "lottie"),
           let data = try? Data(contentsOf: url) {
            return bridge.loadDotlottieData(fileData: data)
        }
        return false
    }

    @discardableResult
    public func loadAnimationData(_ animationData: String) -> Bool {
        reconfigureWebGPUIfNeeded()
        if wgpuContext != nil {
            return bridge.loadAnimationData(animationData: animationData)
        }
        pendingLoad = { [weak self] in
            self?.bridge.loadAnimationData(animationData: animationData) ?? false
        }
        return true
    }

    @discardableResult
    public func loadDotlottie(data: Data) -> Bool {
        reconfigureWebGPUIfNeeded()
        if wgpuContext != nil {
            return bridge.loadDotlottieData(fileData: data)
        }
        pendingLoad = { [weak self, data] in
            self?.bridge.loadDotlottieData(fileData: data) ?? false
        }
        return true
    }

    @discardableResult public func play()  -> Bool { bridge.play() }
    @discardableResult public func pause() -> Bool { bridge.pause() }
    @discardableResult public func stop()  -> Bool { bridge.stop() }

    public var isLoaded:   Bool { bridge.isLoaded() }
    public var isPlaying:  Bool { bridge.isPlaying() }
    public var isPaused:   Bool { bridge.isPaused() }

    public func subscribe(observer: Observer)   { bridge.subscribe(observer: observer) }
    public func unsubscribe(observer: Observer) { bridge.unsubscribe(observer: observer) }

    // MARK: - Deinit

    deinit {
        stopDisplayLink()
        if let ctx = wgpuContext {
            // Tell ThorVG to release its GPU resources first. ThorVG stores the
            // wgpu device/surface as raw unowned pointers, so its destructor would
            // use them after we've freed them. Passing nil triggers WgRenderer::release()
            // which zeroes out mContext.queue — ThorVG's destructor then exits early.
            _ = bridge.setWebGPUTarget(device: nil, instance: nil, target: nil, width: 0, height: 0)

            // freeWebGPUContext drains the GPU queue (waits for all in-flight Metal
            // command buffers to complete) before releasing the device and its
            // internal staging buffers.
            DotLottiePlayer.freeWebGPUContext(context: ctx)
        }
    }
}

#endif
