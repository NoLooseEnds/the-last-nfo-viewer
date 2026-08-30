# Building The Last NFO Viewer

The project requires macOS 11 or later and a full Xcode installation.

## Project structure

- `Sources/` contains the main app source.
- `QuickLook/` contains the Finder Quick Look extension.
- `Resources/` contains assets, fonts, interface files, and localizations.
- `Tests/` contains focused tests for decoding and layout policy.

## Build with Xcode

1. Open `The Last NFO Viewer.xcodeproj`.
2. Select the **The Last NFO Viewer** scheme.
3. Press **Command-B** to build or **Command-R** to run.

The app scheme embeds the Quick Look extension. When changing extension code or resources, also build the **NFO Preview** scheme directly to verify that target.

## Build from Terminal

Build products are kept under `build/DerivedData`:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project "The Last NFO Viewer.xcodeproj" \
  -scheme "The Last NFO Viewer" \
  -configuration Release \
  -derivedDataPath ./build/DerivedData \
  build
```

Verify the Quick Look target separately after extension changes:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project "The Last NFO Viewer.xcodeproj" \
  -scheme "NFO Preview" \
  -configuration Release \
  -derivedDataPath ./build/DerivedData \
  build
```

The resulting app is at:

```text
build/DerivedData/Build/Products/Release/The Last NFO Viewer.app
```

## Run tests

```bash
swift test --scratch-path build/SwiftPM
```

## Test Quick Look

Finder loads app extensions from a stable installed app more reliably than from DerivedData.

1. Replace **The Last NFO Viewer.app** in `/Applications` with the Release build.
2. Open the app once.
3. Select an NFO, ASC, or DIZ file in Finder and press Space.

If Finder still uses an older extension, register the installed copy and refresh the preview services:

```bash
pluginkit -a "/Applications/The Last NFO Viewer.app/Contents/PlugIns/NFO Preview.appex"
pluginkit -e use -i com.nle.TheLastNFOViewer.QuickLook
killall "NFO Preview" 2>/dev/null || true
killall QuickLookUIService 2>/dev/null || true
qlmanage -r cache
```

## Troubleshooting

If `xcodebuild` reports that the active developer directory contains only Command Line Tools, use the `DEVELOPER_DIR` prefix shown above or select Xcode globally with `xcode-select`.

For code-signing failures, open the project in Xcode and confirm that **Sign to Run Locally** is available for both targets.
