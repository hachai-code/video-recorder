#!/bin/sh
set -e
cd "$(dirname "$0")"

swift build -c release
APP=build/Recorder.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Recorder "$APP/Contents/MacOS/"
cp Info.plist "$APP/Contents/"
cp Icon/AppIcon.icns "$APP/Contents/Resources/"
codesign --force --sign - "$APP"
echo "Built $APP"

if [ "$1" = "install" ]; then
    rm -rf /Applications/Recorder.app
    cp -R "$APP" /Applications/
    echo "Installed /Applications/Recorder.app"
fi
