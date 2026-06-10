import SwiftUI
import DotLottie

#if os(iOS) || os(macOS)
struct Example9_WebGPU: View {
    @State private var gpuView: DotLottieWebGPUView?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Example 9: WebGPU Renderer")
                .font(.subheadline)
                .foregroundColor(.secondary)

            DotLottieWebGPUPlayerView(
                fileName: "BrandToggle",
                config: Config(stateMachineId: "StateMachine1")
            )
            { view in
                gpuView = view
            }
            .frame(height: 300)
            .background(Color.black.opacity(0.05))
            .cornerRadius(12)

            Text("Pixels are written directly to a Metal surface via wgpu — no CPU buffer or CGImage conversion.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
    }
}

#Preview {
    ScrollView {
        Example9_WebGPU()
    }
}
#endif
