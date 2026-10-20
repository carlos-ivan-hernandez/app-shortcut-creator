#!/usr/bin/env bash
# Builds "dist/AppShortcutCreator.app". Pass --install to also copy it into /Applications.
# UNIVERSAL=1 builds for both Apple silicon and Intel (requires full Xcode, not just the command line tools).
set -euo pipefail
cd "$(dirname "$0")/.."

arch_flags=()
if [[ "${UNIVERSAL:-0}" == "1" ]]; then
  arch_flags=(--arch arm64 --arch x86_64)
fi

swift build -c release ${arch_flags[@]+"${arch_flags[@]}"}
bin_dir="$(swift build -c release ${arch_flags[@]+"${arch_flags[@]}"} --show-bin-path)"

app="dist/AppShortcutCreator.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp Support/Info.plist "$app/Contents/Info.plist"
cp "$bin_dir/AppShortcutCreator" "$app/Contents/MacOS/AppShortcutCreator"

# The app's icon is Support/AppIcon.png, put on the macOS icon grid by the app itself.
"$app/Contents/MacOS/AppShortcutCreator" icon Support/AppIcon.png "$app/Contents/Resources/AppIcon.icns"

xattr -cr "$app"
codesign --force --sign - "$app"
echo "Built $app"

if [[ "${1:-}" == "--install" ]]; then
  rm -rf "/Applications/AppShortcutCreator.app"
  cp -R "$app" /Applications/
  echo "Installed /Applications/AppShortcutCreator.app"
fi
