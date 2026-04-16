xcodebuild -create-xcframework \
    -framework Sources/DotLottieCore/DotLottiePlayer.xcframework/ios-arm64/DotLottiePlayer.framework \
    -framework Sources/DotLottieCore/DotLottiePlayer.xcframework/ios-arm64_x86_64-simulator/DotLottiePlayer.framework \
    -framework Sources/DotLottieCore/DotLottiePlayer.xcframework/ios-arm64_x86_64-maccatalyst/DotLottiePlayer.framework \
    -framework Sources/DotLottieCore/DotLottiePlayer.xcframework/macos-arm64_x86_64/DotLottiePlayer.framework \
    -framework Sources/DotLottieCore/DotLottiePlayer.xcframework/tvos-arm64/DotLottiePlayer.framework \
    -framework Sources/DotLottieCore/DotLottiePlayer.xcframework/tvos-arm64-simulator/DotLottiePlayer.framework \
    -framework Sources/DotLottieCore/DotLottiePlayer.xcframework/xros-arm64/DotLottiePlayer.framework \
    -framework Sources/DotLottieCore/DotLottiePlayer.xcframework/xros-arm64-simulator/DotLottiePlayer.framework \
    -output Sources/DotLottieCore/cocoapods/DotLottiePlayer.xcframework
