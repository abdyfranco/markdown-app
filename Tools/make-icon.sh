#!/bin/zsh
#
#  make-icon.sh
#  Markdown
#
#  Copyright © 2026 Advandz Technologies, LLC.
#

# Rebuilds the fallback icon and previews from the Icon Composer document.
#
#   Support/AppIcon.icon   the source of truth (open it in Icon Composer)
#   Support/AppIcon.icns   static fallback for builds without Xcode (Default appearance)
#   Support/AppIcon.png    256 px light icon shown at the top of the README
#   build/icon-previews/   a PNG of each appearance, for review
#
# Layer artwork comes from Tools/MakeIconLayers.swift; pass --layers to regenerate it.
set -euo pipefail
cd "${0:A:h}/.."

if [[ "${1:-}" == "--layers" ]]; then
  swift Tools/MakeIconLayers.swift Support/AppIcon.icon/Assets
fi

PREVIEWS="build/icon-previews"
mkdir -p "$PREVIEWS"

# Icon Composer ships inside Xcode 26 (ictool). A standalone Icon Composer
# (icontool, which only accepts relative paths) works as a fallback.
ICTOOL="$(xcode-select -p 2>/dev/null)/../Applications/Icon Composer.app/Contents/Executables/ictool"
if [[ -x "$ICTOOL" ]]; then
  render() {  # rendition size output
    "$ICTOOL" Support/AppIcon.icon --export-image --output-file "$3" --platform macOS \
      --rendition "$1" --width "$2" --height "$2" --scale 1 >/dev/null 2>&1
  }
  RENDITIONS=(Default Dark ClearLight ClearDark TintedLight TintedDark)
else
  ICONTOOL="$(mdfind "kMDItemCFBundleIdentifier == 'com.apple.IconComposer'" | head -1)/Contents/Executables/icontool"
  if [[ ! -x "$ICONTOOL" ]]; then
    echo "Icon Composer is required: install Xcode 26 or get it from developer.apple.com/icon-composer." >&2
    exit 1
  fi
  render() {
    (cd Support && "$ICONTOOL" AppIcon.icon --export-preview macOS "$1" "$2" "$2" 1 "../$3" >/dev/null 2>&1)
  }
  RENDITIONS=(Default Dark Mono)
fi

for rendition in $RENDITIONS; do
  render "$rendition" 512 "$PREVIEWS/AppIcon-$rendition.png"
done

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
render Default 1024 "$PREVIEWS/AppIcon-1024.png"
swift Tools/FrameIcon.swift "$PREVIEWS/AppIcon-1024.png" "$WORK/icon_1024.png"

ICONSET="$WORK/AppIcon.iconset"
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
  sips -z $size $size "$WORK/icon_1024.png" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  sips -z $((size * 2)) $((size * 2)) "$WORK/icon_1024.png" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o Support/AppIcon.icns
sips -z 256 256 "$WORK/icon_1024.png" --out Support/AppIcon.png >/dev/null
echo "✓ Support/AppIcon.icns and AppIcon.png updated; previews in $PREVIEWS"
