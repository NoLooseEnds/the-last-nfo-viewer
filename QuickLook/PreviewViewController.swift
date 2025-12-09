import Cocoa
import Quartz

class PreviewViewController: NSViewController, QLPreviewingController {
    
    private var textView: NSTextView!
    
    private var sharedConfig: [String: Any] = [:]
    
    override func loadView() {
        loadSharedConfig()
        
        let scrollView = NSScrollView()
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        
        let contentSize = NSSize(width: 800, height: 600)
        scrollView.frame = NSRect(origin: .zero, size: contentSize)
        
        textView = NSTextView()
        textView.minSize = NSSize(width: 0, height: contentSize.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        
        textView.textContainer?.containerSize = NSSize(width: contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        
        textView.isEditable = false
        textView.isSelectable = true
        
        scrollView.documentView = textView
        self.view = scrollView
        
        // Setup theme support
        updateAppearance()
        
        // Observe theme changes
        DistributedNotificationCenter.default.addObserver(self, selector: #selector(themeChanged), name: NSNotification.Name("AppleInterfaceThemeChangedNotification"), object: nil)
    }
    
    deinit {
        DistributedNotificationCenter.default.removeObserver(self)
    }
    
    @objc private func themeChanged() {
        updateAppearance()
    }
    
    private func updateAppearance() {
        let appearance = NSApp.effectiveAppearance
        
        let modeString = (sharedConfig["appearanceMode"] as? String) ?? "System"
        let isEffectiveDark: Bool
        
        switch modeString {
        case "Dark": isEffectiveDark = true
        case "Light": isEffectiveDark = false
        default: // System
            isEffectiveDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        }
        
        // Colors
        if let textHex = sharedConfig["textColor"] as? String,
           let bgHex = sharedConfig["backgroundColor"] as? String {
            textView.textColor = color(from: textHex)
            textView.backgroundColor = color(from: bgHex)
        } else {
            if isEffectiveDark {
                textView.backgroundColor = .black
                textView.textColor = .white
            } else {
                textView.backgroundColor = .white
                textView.textColor = .black
            }
        }
        
        if let linkHex = sharedConfig["linkColor"] as? String {
             textView.linkTextAttributes = [.foregroundColor: color(from: linkHex), .cursor: NSCursor.pointingHand]
        }
        
        if let selHex = sharedConfig["selectionColor"] as? String {
            textView.selectedTextAttributes = [.backgroundColor: color(from: selHex)]
        }
    }
    
    private func color(from hex: String) -> NSColor {
        var cString: String = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        if (cString.hasPrefix("#")) {
            cString.remove(at: cString.startIndex)
        }

        if ((cString.count) != 6) {
            return .gray
        }

        var rgbValue: UInt64 = 0
        Scanner(string: cString).scanHexInt64(&rgbValue)

        return NSColor(
            red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
            alpha: CGFloat(1.0)
        )
    }
    
    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        // Try to register custom font
        registerFont()
        
        do {
            let startAccess = url.startAccessingSecurityScopedResource()
            defer { if startAccess { url.stopAccessingSecurityScopedResource() } }
            
            let data = try Data(contentsOf: url)
            
            // CP437 Decoding
            let cfEncoding = CFStringConvertWindowsCodepageToEncoding(437)
            let nsEncoding = CFStringConvertEncodingToNSStringEncoding(cfEncoding)
            let encoding = String.Encoding(rawValue: nsEncoding)
            
            var content = String(data: data, encoding: encoding) ?? String(data: data, encoding: .ascii) ?? "Error decoding file content."
            
            // Remove trailing CR/LF
             if content.hasSuffix("\n") {
                 content = String(content.dropLast())
                 if content.hasSuffix("\r") {
                     content = String(content.dropLast())
                 }
             }

            DispatchQueue.main.async {
                self.updateText(content)
                handler(nil)
            }
        } catch {
            let errorMsg = "Failed to read file: \(error.localizedDescription)"
            DispatchQueue.main.async {
                self.updateText(errorMsg)
                handler(nil)
            }
        }
    }
    
    private func registerFont() {
        // Register all fonts found in the bundle to ensure the selected one is available
        let bundle = Bundle(for: type(of: self))
        if let urls = bundle.urls(forResourcesWithExtension: "ttf", subdirectory: nil) {
            CTFontManagerRegisterFontsForURLs(urls as CFArray, .process, nil)
        }
    }
    
    private func getRealHomeDirectory() -> URL? {
        // Use standard FileManager API which is safer in sandbox than getpwuid
        return FileManager.default.homeDirectoryForCurrentUser
    }
    
    private func loadSharedConfig() {
        guard let home = getRealHomeDirectory() else { return }
        let url = home.appendingPathComponent(".the-last-nfo-viewer.json")
        
        do {
            let data = try Data(contentsOf: url)
            if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                self.sharedConfig = json
            }
        } catch {
            print("Failed to load shared config: \(error)")
        }
    }
    
    private func updateText(_ content: String) {
        let fontSize = (sharedConfig["fontSize"] as? Double) ?? 14.0
        let fontName = (sharedConfig["fontName"] as? String) ?? "More Perfect DOS VGA"
        
        // Try custom font first, fallback to user fixed pitch, then system mono
        let font = NSFont(name: fontName, size: fontSize) 
            ?? NSFont.userFixedPitchFont(ofSize: fontSize) 
            ?? NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        
        textView.font = font
        textView.string = content
        
        if let highlight = sharedConfig["highlightLinks"] as? Bool, highlight {
            textView.checkTextInDocument(nil)
        }
        
        // Ensure colors are correct after setting string (sometimes resets attributes)
        updateAppearance()
    }
}
