#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:?Usage: build-binary-release.sh VERSION}"
OUTPUT="${2:-$ROOT/Distribution/output/$VERSION}"
IOS_MIN="${IOS_MIN:-15.0}"
SDK_DEVICE="$(xcrun --sdk iphoneos --show-sdk-path)"
SDK_SIM="$(xcrun --sdk iphonesimulator --show-sdk-path)"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
mkdir -p "$OUTPUT" "$T/module-cache"
rm -rf "$OUTPUT/iphoneos" "$OUTPUT/iphonesimulator" \
  "$OUTPUT/MyLibrarySDKCoreBinary.xcframework" \
  "$OUTPUT/MyLibrarySDKFeatureBinary.xcframework" \
  "$OUTPUT/MyLibrarySDKCoreBinary-$VERSION.zip" \
  "$OUTPUT/MyLibrarySDKFeatureBinary-$VERSION.zip" \
  "$OUTPUT/MyLibrarySDKCoreBinary-$VERSION.sha256" \
  "$OUTPUT/MyLibrarySDKFeatureBinary-$VERSION.sha256"

make_framework() {
  local name platform arch sdk target destination framework source_dir module_target file
  local -a sources args
  name="$1"; platform="$2"; arch="$3"; sdk="$4"; target="$5"; destination="$6"
  framework="$destination/$name.framework"
  mkdir -p "$framework/Modules/$name.swiftmodule"
  source_dir="$name"
  [[ "$name" == "MyLibrarySDKCoreBinary" ]] && source_dir="MyLibrarySDKCore"
  [[ "$name" == "MyLibrarySDKFeatureBinary" ]] && source_dir="MyLibrarySDKFeature"
  module_target="$arch-apple-ios"
  [[ "$platform" == "iphonesimulator" ]] && module_target="$module_target-simulator"
  sources=()
  while IFS= read -r file; do sources+=("$file"); done < <(find "$ROOT/$source_dir/Sources" -type f -name '*.swift' | sort)
  args=("${sources[@]}" -sdk "$sdk" -target "$target" -parse-as-library
    -module-name "$name" -swift-version 5 -module-cache-path "$T/module-cache" -emit-library -emit-module -emit-module-interface
    -enable-library-evolution -O -Xlinker -install_name
    -Xlinker "@rpath/$name.framework/$name"
    -o "$framework/$name"
    -emit-module-path "$framework/Modules/$name.swiftmodule/$module_target.swiftmodule"
    -emit-module-interface-path "$framework/Modules/$name.swiftmodule/$module_target.swiftinterface")
  if [[ "$name" == "MyLibrarySDKFeatureBinary" ]]; then
    args+=( -F "$T/$platform/$arch" -framework MyLibrarySDKCoreBinary )
  fi
  swiftc "${args[@]}"
  cat > "$framework/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>$name</string>
<key>CFBundleIdentifier</key><string>com.mylibrary.$name</string>
<key>CFBundleName</key><string>$name</string>
<key>CFBundlePackageType</key><string>FMWK</string>
<key>MinimumOSVersion</key><string>$IOS_MIN</string>
<key>DTPlatformName</key><string>$platform</string>
</dict></plist>
PLIST
}

build_target() {
  local name platform destination arch sdk target archdir framework final module_target i
  local -a archs frameworks bins
  name="$1"; platform="$2"; destination="$3"
  archs=(arm64)
  if [[ "$platform" == "iphonesimulator" ]]; then archs+=(x86_64); fi
  frameworks=()
  for arch in "${archs[@]}"; do
    sdk="$SDK_DEVICE"; target="$arch-apple-ios$IOS_MIN"
    if [[ "$platform" == "iphonesimulator" ]]; then
      sdk="$SDK_SIM"; target="$arch-apple-ios$IOS_MIN-simulator"
    fi
    archdir="$T/$platform/$arch"
    mkdir -p "$archdir"
    make_framework "$name" "$platform" "$arch" "$sdk" "$target" "$archdir"
    frameworks+=("$archdir/$name.framework")
  done
  final="$destination/$name.framework"
  cp -R "${frameworks[0]}" "$final"
  if (( ${#frameworks[@]} > 1 )); then
    bins=()
    for framework in "${frameworks[@]}"; do bins+=("$framework/$name"); done
    lipo -create "${bins[@]}" -output "$final/$name"
    for i in "${!frameworks[@]}"; do
      arch="${archs[$i]}"
      module_target="$arch-apple-ios-simulator"
      cp "${frameworks[$i]}/Modules/$name.swiftmodule/$module_target.swiftmodule" "$final/Modules/$name.swiftmodule/"
      cp "${frameworks[$i]}/Modules/$name.swiftmodule/$module_target.swiftinterface" "$final/Modules/$name.swiftmodule/"
    done
  fi
}

# Build Core first so Feature can import and link its module.
for platform in iphoneos iphonesimulator; do
  destination="$OUTPUT/$platform"
  mkdir -p "$destination"
  build_target MyLibrarySDKCoreBinary "$platform" "$destination"
  build_target MyLibrarySDKFeatureBinary "$platform" "$destination"
done

for name in MyLibrarySDKCoreBinary MyLibrarySDKFeatureBinary; do
  xcodebuild -create-xcframework \
    -framework "$OUTPUT/iphoneos/$name.framework" \
    -framework "$OUTPUT/iphonesimulator/$name.framework" \
    -output "$OUTPUT/$name.xcframework"
  ditto -c -k --sequesterRsrc --keepParent "$OUTPUT/$name.xcframework" "$OUTPUT/$name-$VERSION.zip"
  shasum -a 256 "$OUTPUT/$name-$VERSION.zip" | awk '{print $1}' > "$OUTPUT/$name-$VERSION.sha256"
done
echo "Created binary artifacts in $OUTPUT"
