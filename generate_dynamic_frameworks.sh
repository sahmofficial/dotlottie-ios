#!/bin/bash
#
# Prepares the xcframeworks for CocoaPods distribution.
#
#  * DotLottiePlayer: re-packaged from the SPM xcframework with the watchOS
#    slices removed (CocoaPods integration doesn't need them).
#  * WgpuNative: the SPM xcframework ships raw .dylib slices, which CocoaPods
#    rejects ("contains dynamic libraries which are not supported"). Each slice
#    is wrapped into a proper WgpuNative.framework before assembling the
#    xcframework.
#
# Outputs land in Sources/DotLottieCore/cocoapods/.

set -euo pipefail

ROOT="Sources/DotLottieCore"
WGPU_SRC="$ROOT/WgpuNative.xcframework"
COCOAPODS_DIR="$ROOT/cocoapods"
BUILD_DIR="$COCOAPODS_DIR/.wgpu-frameworks"

# ---------------------------------------------------------------------------
# DotLottiePlayer — framework-based, just drop the watchOS slices.
# ---------------------------------------------------------------------------
rm -rf "$COCOAPODS_DIR/DotLottiePlayer.xcframework"
xcodebuild -create-xcframework \
    -framework "$ROOT/DotLottiePlayer.xcframework/ios-arm64/DotLottiePlayer.framework" \
    -framework "$ROOT/DotLottiePlayer.xcframework/ios-arm64_x86_64-simulator/DotLottiePlayer.framework" \
    -framework "$ROOT/DotLottiePlayer.xcframework/ios-arm64_x86_64-maccatalyst/DotLottiePlayer.framework" \
    -framework "$ROOT/DotLottiePlayer.xcframework/macos-arm64_x86_64/DotLottiePlayer.framework" \
    -framework "$ROOT/DotLottiePlayer.xcframework/tvos-arm64/DotLottiePlayer.framework" \
    -framework "$ROOT/DotLottiePlayer.xcframework/tvos-arm64-simulator/DotLottiePlayer.framework" \
    -framework "$ROOT/DotLottiePlayer.xcframework/xros-arm64/DotLottiePlayer.framework" \
    -framework "$ROOT/DotLottiePlayer.xcframework/xros-arm64-simulator/DotLottiePlayer.framework" \
    -output "$COCOAPODS_DIR/DotLottiePlayer.xcframework"

# ---------------------------------------------------------------------------
# WgpuNative — wrap each .dylib slice into a WgpuNative.framework.
# ---------------------------------------------------------------------------

write_modulemap() {
    cat > "$1" <<'EOF'
framework module WgpuNative {
  header "webgpu/wgpu.h"
  export *
}
EOF
}

# write_plist <path> <ios|macos>
write_plist() {
    local plist="$1" platform="$2"
    cat > "$plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleExecutable</key>
	<string>WgpuNative</string>
	<key>CFBundleIdentifier</key>
	<string>com.lottiefiles.WgpuNative</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>WgpuNative</string>
	<key>CFBundlePackageType</key>
	<string>FMWK</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0</string>
	<key>CFBundleVersion</key>
	<string>1</string>
EOF
    if [ "$platform" = "ios" ]; then
        cat >> "$plist" <<'EOF'
	<key>MinimumOSVersion</key>
	<string>13.0</string>
EOF
    else
        cat >> "$plist" <<'EOF'
	<key>LSMinimumSystemVersion</key>
	<string>11.0</string>
EOF
    fi
    cat >> "$plist" <<'EOF'
</dict>
</plist>
EOF
}

# make_framework <slice> <ios|macos>
make_framework() {
    local slice="$1" platform="$2"
    local src="$WGPU_SRC/$slice"
    local fw="$BUILD_DIR/$slice/WgpuNative.framework"
    rm -rf "$fw"

    if [ "$platform" = "macos" ]; then
        # Deep / versioned bundle layout required for macOS frameworks.
        local ver="$fw/Versions/A"
        mkdir -p "$ver/Headers" "$ver/Modules" "$ver/Resources"
        cp "$src/libwgpu_native.dylib" "$ver/WgpuNative"
        install_name_tool -id "@rpath/WgpuNative.framework/Versions/A/WgpuNative" "$ver/WgpuNative"
        cp -R "$src/Headers/webgpu" "$ver/Headers/webgpu"
        write_modulemap "$ver/Modules/module.modulemap"
        write_plist "$ver/Resources/Info.plist" macos
        ln -sf A "$fw/Versions/Current"
        ln -sf Versions/Current/WgpuNative "$fw/WgpuNative"
        ln -sf Versions/Current/Headers "$fw/Headers"
        ln -sf Versions/Current/Modules "$fw/Modules"
        ln -sf Versions/Current/Resources "$fw/Resources"
    else
        # Flat bundle layout for iOS / simulator frameworks.
        mkdir -p "$fw/Headers" "$fw/Modules"
        cp "$src/libwgpu_native.dylib" "$fw/WgpuNative"
        install_name_tool -id "@rpath/WgpuNative.framework/WgpuNative" "$fw/WgpuNative"
        cp -R "$src/Headers/webgpu" "$fw/Headers/webgpu"
        write_modulemap "$fw/Modules/module.modulemap"
        write_plist "$fw/Info.plist" ios
    fi
}

rm -rf "$BUILD_DIR" "$COCOAPODS_DIR/WgpuNative.xcframework"
make_framework "ios-arm64" ios
make_framework "ios-arm64_x86_64-simulator" ios
make_framework "macos-arm64_x86_64" macos

xcodebuild -create-xcframework \
    -framework "$BUILD_DIR/ios-arm64/WgpuNative.framework" \
    -framework "$BUILD_DIR/ios-arm64_x86_64-simulator/WgpuNative.framework" \
    -framework "$BUILD_DIR/macos-arm64_x86_64/WgpuNative.framework" \
    -output "$COCOAPODS_DIR/WgpuNative.xcframework"

rm -rf "$BUILD_DIR"
