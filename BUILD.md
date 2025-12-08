# Building The Last NFO Viewer

## 1. Project Structure
The project is organized to keep the root directory clean:
- **`Sources/`**: All Swift source code (`AppDelegate.swift`, `ViewController.swift`, etc.).
- **`Resources/`**: Assets including `Assets.xcassets` (App Icon), Fonts, XIBs, and Localization files.
- **`QuickLook/`**: Source code for the QuickLook plugin.

## 2. How to Build

### Option A: Using Xcode (Recommended)
1. Open `The Last NFO Viewer.xcodeproj`.
2. Select the **The Last NFO Viewer** scheme.
3. Press **Cmd+B** to build or **Cmd+R** to run.

### Option B: Using Terminal
**Important:** If you see `xcode-select` errors or "Operation not permitted", follow these steps carefully.

1. **Ensure correct Xcode path:**
   The Command Line Tools (CLT) path often causes build failures. Force the use of the full Xcode app:
   ```bash
   export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
   ```

2. **Clean previous builds:**
   ```bash
   rm -rf build/
   ```

3. **Build the Main App:**
   ```bash
   xcodebuild -project "The Last NFO Viewer.xcodeproj" \
     -scheme "The Last NFO Viewer" \
     -configuration Release \
     -derivedDataPath ./build/DerivedData \
     build
   ```

4. **Build the QuickLook Plugin:**
   ```bash
   xcodebuild -project "The Last NFO Viewer.xcodeproj" \
     -scheme "NFO Preview" \
     -configuration Release \
     -derivedDataPath ./build/DerivedData \
     build
   ```

## 3. Where are the files?
After a successful terminal build using the commands above, your application will be located here:
`./build/DerivedData/Build/Products/Release/The Last NFO Viewer.app`

## 4. Common Troubleshooting

**Error:** `xcode-select: error: tool 'xcodebuild' requires Xcode, but active developer directory...`
**Fix:** Run `export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"` before building.

**Error:** `Operation not permitted` / `sandbox` errors
**Fix:** This happens when running inside strict sandboxed environments (like some AI agents or restricted shells). Run the commands in your system's standard **Terminal.app** or **iTerm**.

**Error:** `CodeSigning` errors
**Fix:** The project is set to "Sign to Run Locally". If this fails, ensure you have a valid development certificate or open the project in Xcode to let it repair signing automatically.