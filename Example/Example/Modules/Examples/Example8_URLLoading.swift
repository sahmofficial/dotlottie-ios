//
//  Example8_URLLoading.swift
//  DotLottieIosTestApp
//
//  Load an animation from a remote URL
//

import SwiftUI
import DotLottie

struct Example8_URLLoading: View {
    private let animationURL = "https://lottie.host/4db68bbd-31f6-4cd8-84eb-189de081159a/IGmMCqhzpt.lottie"

    @State private var animation: DotLottieAnimation? = nil
    @State private var loadState: LoadState = .loading
    @State private var loadObserver: LoadObserver?

    enum LoadState { case loading, loaded, failed }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Example 8: URL Loading")
                .font(.subheadline)
                .foregroundColor(.secondary)

            ZStack {
                if let animation {
                    DotLottiePlayerView(animation: animation)
                        .looping()
                        .frame(height: 200)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                        .opacity(loadState == .loaded ? 1 : 0)
                }

                if loadState == .loading {
                    VStack(spacing: 8) {
                        ProgressView()
                        Text("Loading from URL…")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: 200)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                }

                if loadState == .failed {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.title2)
                            .foregroundColor(.orange)
                        Text("Failed to load animation")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: 200)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                }
            }

            HStack {
                Image(systemName: loadState == .loaded ? "checkmark.circle.fill" : "arrow.down.circle")
                    .foregroundColor(loadState == .loaded ? .green : .secondary)
                Text(loadState == .loaded ? "Loaded from URL" : animationURL)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Button {
                startLoading()
            } label: {
                Label("Reload", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal)
        .onAppear {
            startLoading()
        }
    }

    private func startLoading() {
        loadState = .loading
        let anim = DotLottieAnimation(
            webURL: animationURL,
            config: AnimationConfig(autoplay: true, loop: true)
        )
        let obs = LoadObserver(
            onLoaded: { [anim] in _ = anim.play(); loadState = .loaded },
            onFailed: { loadState = .failed }
        )
        anim.subscribe(observer: obs)
        loadObserver = obs
        animation = anim
    }
}

private class LoadObserver: Observer {
    private let onLoaded: () -> Void
    private let onFailed: () -> Void

    init(onLoaded: @escaping () -> Void, onFailed: @escaping () -> Void) {
        self.onLoaded = onLoaded
        self.onFailed = onFailed
    }

    func onLoad() { onLoaded() }
    func onLoadError() { onFailed() }
    func onPlay() {}
    func onPause() {}
    func onStop() {}
    func onFrame(frameNo: Float) {}
    func onRender(frameNo: Float) {}
    func onLoop(loopCount: UInt32) {}
    func onComplete() {}
}
