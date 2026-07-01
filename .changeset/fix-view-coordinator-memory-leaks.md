---
"DotLottie": patch
---

Fix memory leaks caused by retain cycles in the view/coordinator layer

- `Coordinator` now captures the shared `DotLottieAnimation` view model instead of the parent view, breaking the `view <-> coordinator` retain cycle on the UIKit (`DotLottieAnimationView`) path that kept the view and its Metal resources alive forever.
- `Coordinator` (macOS) stores the block-based `NotificationCenter` screen-change observer token and removes it in `deinit`; `removeObserver(self)` does not unregister block-based observers, so the registration leaked for every `Coordinator` created.
- `DotLottieWebGPUView` routes its `CADisplayLink` through a weak proxy so the link no longer retains the view, allowing `deinit` (and GPU resource cleanup) to run.
- `DotLottieAnimationView` captures `self` weakly in the `framerate` subscription closure.
- `DotLottieObserver` holds `observedPlayer` weakly to avoid a `Player <-> observer` retain cycle.
