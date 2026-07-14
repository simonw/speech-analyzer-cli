#!/bin/bash
set -euo pipefail

prefix="${PREFIX:-$HOME/.local}"
app_dir="$prefix/libexec/SpeechAnalyzerCLI.app"
bin_dir="$prefix/bin"

swift build -c release

mkdir -p "$app_dir/Contents/MacOS" "$bin_dir"
cp Resources/Info.plist "$app_dir/Contents/Info.plist"
cp .build/release/speech-analyzer "$app_dir/Contents/MacOS/speech-analyzer"

# Ad-hoc signing gives macOS a coherent application bundle. A real Apple
# Development signature can be applied afterwards if desired.
codesign --force --deep --sign - "$app_dir"

ln -sfn "$app_dir/Contents/MacOS/speech-analyzer" "$bin_dir/speech-analyzer"

echo "Installed $bin_dir/speech-analyzer"
case ":$PATH:" in
    *":$bin_dir:"*) ;;
    *) echo "Add $bin_dir to PATH to run it without a full path." ;;
esac
