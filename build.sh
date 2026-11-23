#!/bin/bash
set -eu
cd "$(dirname "$0")"
dest=Knotwork.app/Contents
mkdir -p "$dest/MacOS" "$dest/Resources"
mkdir -p "$dest/Resources/Audio"
cp Resources/Oh.wav "$dest/Resources/"
rsync -a --delete Resources/Audio/ "$dest/Resources/Audio/"
xcrun swiftc -O -target "$(uname -m)-apple-macos12.0" Sources/*.swift -o "$dest/MacOS/Knotwork"
cp Info.plist "$dest/"
codesign --force --sign - Knotwork.app
