#!/bin/bash
# Builds ios/plugins/bonjour.{debug,release}.xcframework (device + simulator, arm64).
# Usage: GODOT_SRC=/path/to/godot-4.7.2-stable-checkout SCONS=/path/to/scons ./build.sh
# Godot generates a few headers the plugin includes; requested one at a time from scons on demand.
set -euo pipefail
: "${GODOT_SRC:?set GODOT_SRC to a Godot source checkout matching the editor version}"
SCONS=${SCONS:-scons}
HERE=$(cd "$(dirname "$0")" && pwd)
OUT=$HERE/../ios/plugins
BUILD=$(mktemp -d)

compile() { # variant sdk min-flag src obj
  local variant=$1 sdk=$2 minflag=$3 src=$4 obj=$5
  local std=gnu++17 flags=(-DNDEBUG)
  [ "$variant" = debug ] && flags=(-DDEBUG_ENABLED -D_DEBUG)
  [[ $src == *.mm ]] && flags+=(-fobjc-arc -fmodules -fcxx-modules)
  while true; do
    if out=$(clang++ -c "$src" -o "$obj" -std=$std -arch arm64 -isysroot "$(xcrun --sdk $sdk --show-sdk-path)" $minflag \
        -I"$GODOT_SRC" -I"$GODOT_SRC/platform/ios" -DIOS_ENABLED -DUNIX_ENABLED -DVULKAN_ENABLED -DPTRCALL_ENABLED \
        -fno-exceptions -fvisibility=hidden "${flags[@]}" 2>&1); then return; fi
    miss=$(echo "$out" | grep -o "'[A-Za-z_/]*\.gen\.h' file not found" | head -1 | cut -d"'" -f2)
    [ -z "$miss" ] && { echo "$out"; exit 1; }
    (cd "$GODOT_SRC" && $SCONS platform=ios target=template_$([ "$variant" = debug ] && echo debug || echo release) arch=arm64 "$miss" >/dev/null)
  done
}

for variant in debug release; do
  args=()
  for sdk in iphoneos iphonesimulator; do
    minflag=-miphoneos-version-min=15.0
    [ $sdk = iphonesimulator ] && minflag=-mios-simulator-version-min=15.0
    d=$BUILD/$variant-$sdk; mkdir -p "$d"
    for src in bonjour.mm bonjour_module.cpp; do compile $variant $sdk $minflag "$HERE/bonjour/$src" "$d/${src%.*}.o"; done
    libtool -static -o "$d/libbonjour.a" "$d"/*.o
    args+=(-library "$d/libbonjour.a")
  done
  rm -rf "$OUT/bonjour.$variant.xcframework"
  xcodebuild -create-xcframework "${args[@]}" -output "$OUT/bonjour.$variant.xcframework"
done
rm -rf "$BUILD"
