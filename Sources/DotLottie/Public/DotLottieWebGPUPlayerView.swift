#if canImport(SwiftUI) && (os(iOS) || os(macOS))
import SwiftUI

/// A SwiftUI view that renders a Lottie animation via WebGPU (Metal backend).
///
/// Wraps `DotLottieWebGPUView` as a `ViewRepresentable`. Use this in SwiftUI
/// hierarchies the same way you would use `DotLottieView` for the software renderer.
///
/// Example:
/// ```swift
/// DotLottieWebGPUPlayerView(
///     fileName: "my_animation",
///     config: Config(autoplay: true, loopAnimation: true)
/// )
/// .frame(width: 300, height: 300)
/// ```
public struct DotLottieWebGPUPlayerView: ViewRepresentable {
    public typealias UIViewType = DotLottieWebGPUView

    private let config: Config
    private let fileName: String?
    private let animationData: String?
    private let bundle: Bundle

    // MARK: - Init

    /// Load from a .json or .lottie file in the given bundle.
    public init(
        fileName: String,
        bundle: Bundle = .main,
        config: Config = Config()
    ) {
        self.fileName = fileName
        self.animationData = nil
        self.bundle = bundle
        self.config = config
    }

    /// Load from an in-memory Lottie JSON string.
    public init(
        animationData: String,
        config: Config = Config()
    ) {
        self.fileName = nil
        self.animationData = animationData
        self.bundle = .main
        self.config = config
    }

    // MARK: - ViewRepresentable

    public func makeView(context: Context) -> DotLottieWebGPUView {
        let view = DotLottieWebGPUView(config: config)
        if let name = fileName {
            view.loadAnimation(fileName: name, bundle: bundle)
        } else if let data = animationData {
            view.loadAnimationData(data)
        }
        return view
    }

    public func updateView(_ view: DotLottieWebGPUView, context: Context) {}
}

#endif
