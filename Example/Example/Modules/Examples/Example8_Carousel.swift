//
//  Example8_Carousel.swift
//  Example
//
//  Carousel of remote .lottie animations loaded from URLs
//

import SwiftUI
import DotLottie

private struct CarouselItem: Identifiable {
    let id = UUID()
    let title: String
    let url: String
}

private let carouselItems: [CarouselItem] = [
    CarouselItem(
        title: "Diversification Score",
        url: "https://assets.tickertape.in/lottie/assetLandingPage/diversification_score.lottie"
    ),
    CarouselItem(
        title: "Alerts on Investment",
        url: "https://assets.tickertape.in/lottie/assetLandingPage/alerts_on_investment.lottie"
    ),
    CarouselItem(
        title: "Compare XIRR",
        url: "https://assets.tickertape.in/lottie/assetLandingPage/compare_XIRR.lottie"
    ),
    CarouselItem(
        title: "Forecast",
        url: "https://assets.tickertape.in/lottie/assetLandingPage/forecast.lottie"
    ),
    CarouselItem(
        title: "Red Flags",
        url: "https://assets.tickertape.in/lottie/assetLandingPage/red_flags.lottie"
    ),
]

// Loads animations one at a time. Concurrent dotlottie_load_dotlottie_data calls share
// mutable state in the Rust DotLottieManager and cause heap corruption / crashes.
@MainActor
private final class CarouselViewModel: ObservableObject {
    @Published var animations: [DotLottieAnimation?]
    private var loadTask: Task<Void, Never>?

    init(items: [CarouselItem]) {
        animations = Array(repeating: nil, count: items.count)
        loadTask = Task { [weak self] in
            await self?.loadSequentially(items: items)
        }
    }

    deinit {
        loadTask?.cancel()
    }

    private func loadSequentially(items: [CarouselItem]) async {
        for (index, item) in items.enumerated() {
            guard !Task.isCancelled else { return }

            let animation = DotLottieAnimation(
                webURL: item.url,
                config: AnimationConfig(autoplay: true, loop: true)
            )

            // Poll until the internal Task (which calls loadDotlottieData on the Rust side)
            // completes before starting the next load.
//            var ticks = 0
//            while !animation.isLoaded() && !animation.error() {
//                guard !Task.isCancelled else { return }
//                try? await Task.sleep(nanoseconds: 50_000_000) // 50 ms
//                ticks += 1
//                if ticks > 400 { break } // 20 s safety timeout
//            }

            animations[index] = animation
        }
    }
}

struct Example8_Carousel: View {
    @StateObject private var viewModel = CarouselViewModel(items: carouselItems)
    @State private var currentIndex = 0

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentIndex) {
                ForEach(Array(carouselItems.enumerated()), id: \.element.id) { index, item in
                    CarouselCard(animation: viewModel.animations[index])
                        .tag(index)
                        .padding(.horizontal, 16)
                }
            }
//            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 360)

            PageIndicator(total: carouselItems.count, current: currentIndex)
                .padding(.top, 12)

            Text(carouselItems[currentIndex].title)
                .font(.headline)
                .multilineTextAlignment(.center)
                .animation(.easeInOut(duration: 0.2), value: currentIndex)
                .padding(.top, 8)
                .padding(.horizontal)
        }
        .navigationTitle("Animation Carousel")
    }
}

private struct CarouselCard: View {
    let animation: DotLottieAnimation?

    var body: some View {
        ZStack {
            if let animation {
                DotLottiePlayerView(animation: animation)
                    .playing()
                    .looping()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Loading…")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
//        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
    }
}

private struct PageIndicator: View {
    let total: Int
    let current: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { i in
                Capsule()
                    .fill(i == current ? Color.accentColor : Color.secondary.opacity(0.35))
                    .frame(width: i == current ? 20 : 8, height: 8)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: current)
            }
        }
    }
}

#Preview {
    NavigationView {
        Example8_Carousel()
    }
}
