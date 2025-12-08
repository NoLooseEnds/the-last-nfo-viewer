import Cocoa

class ThemeManager {
    static let shared = ThemeManager()
    
    private init() {}
    
    var defaults: UserDefaults {
        return UserDefaults.standard
    }
    
    // MARK: - Appearance Logic
    
    enum ThemeMode {
        case light
        case dark
        case system
    }
    
    var currentMode: ThemeMode {
        let modeString = defaults.string(forKey: Constants.Defaults.appearanceMode) ?? "System"
        switch modeString {
        case "Light": return .light
        case "Dark": return .dark
        default: return .system
        }
    }
    
    var isEffectiveDark: Bool {
        switch currentMode {
        case .dark: return true
        case .light: return false
        case .system:
            return NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        }
    }
    
    func applyAppearance(to window: NSWindow?) {
        guard let window = window else { return }
        
        switch currentMode {
        case .dark:
            window.appearance = NSAppearance(named: .darkAqua)
        case .light:
            window.appearance = NSAppearance(named: .aqua)
        case .system:
            window.appearance = nil // Follow system
        }
    }
    
    func setAppearanceMode(_ mode: String) {
        defaults.set(mode, forKey: Constants.Defaults.appearanceMode)
        
        // Reset custom colors to defaults when mode changes
        // This prevents "Black text on Black background" scenarios when switching modes
        defaults.removeObject(forKey: Constants.Defaults.textColor)
        defaults.removeObject(forKey: Constants.Defaults.backgroundColor)
        
        notifyPreferencesChanged()
    }
    
    func toggleDarkMode() {
        let newMode: String
        let current = currentMode
        
        // If system, toggle to opposite of current effective appearance
        if current == .system {
            newMode = isEffectiveDark ? "Light" : "Dark"
        } else if current == .dark {
            newMode = "Light"
        } else {
            newMode = "Dark"
        }
        
        setAppearanceMode(newMode)
    }
    
    // MARK: - Font Management
    
    func increaseFontSize() {
        var size = defaults.double(forKey: Constants.Defaults.fontSize)
        if size == 0 { size = 14.0 }
        size += 1.0
        if size > 72.0 { size = 72.0 }
        
        defaults.set(size, forKey: Constants.Defaults.fontSize)
        notifyPreferencesChanged()
    }
    
    func decreaseFontSize() {
        var size = defaults.double(forKey: Constants.Defaults.fontSize)
        if size == 0 { size = 14.0 }
        size -= 1.0
        if size < 8.0 { size = 8.0 }
        
        defaults.set(size, forKey: Constants.Defaults.fontSize)
        notifyPreferencesChanged()
    }
    
    func resetFontSize() {
        defaults.set(14.0, forKey: Constants.Defaults.fontSize)
        notifyPreferencesChanged()
    }
    
    // MARK: - Shared Config (Workaround for App Groups)
    
    private func getRealHomeDirectory() -> URL? {
        if let pw = getpwuid(getuid()), let homeDir = String(validatingUTF8: pw.pointee.pw_dir) {
            return URL(fileURLWithPath: homeDir)
        }
        return nil
    }

    private func exportSharedConfig() {
        let config: [String: Any] = [
            "fontName": defaults.string(forKey: Constants.Defaults.fontName) ?? "More Perfect DOS VGA",
            "fontSize": defaults.double(forKey: Constants.Defaults.fontSize),
            "appearanceMode": defaults.string(forKey: Constants.Defaults.appearanceMode) ?? "System",
            "highlightLinks": defaults.bool(forKey: Constants.Defaults.highlightLinks),
            "textColor": hexString(from: textColor),
            "backgroundColor": hexString(from: backgroundColor),
            "linkColor": hexString(from: linkColor),
            "selectionColor": hexString(from: selectionColor)
        ]
        
        guard let home = getRealHomeDirectory() else { return }
        let url = home.appendingPathComponent(".the-last-nfo-viewer.json")
        
        do {
            let data = try JSONSerialization.data(withJSONObject: config, options: .prettyPrinted)
            try data.write(to: url)
        } catch {
            print("Failed to write shared config: \(error)")
        }
    }
    
    private func hexString(from color: NSColor) -> String {
        guard let rgbColor = color.usingColorSpace(.sRGB) else { return "#000000" }
        let r = Int(round(rgbColor.redComponent * 255))
        let g = Int(round(rgbColor.greenComponent * 255))
        let b = Int(round(rgbColor.blueComponent * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }
    
    // Call this whenever preferences change
    func notifyPreferencesChanged() {
        exportSharedConfig()
        NotificationCenter.default.post(name: Constants.Notifications.preferencesChanged, object: nil)
    }
    
    // MARK: - Color Resolution
    
    var textColor: NSColor {
        if let data = defaults.data(forKey: Constants.Defaults.textColor),
           let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data) {
            return color
        }
        return isEffectiveDark ? .white : .black
    }
    
    var backgroundColor: NSColor {
        if let data = defaults.data(forKey: Constants.Defaults.backgroundColor),
           let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data) {
            return color
        }
        return isEffectiveDark ? .black : .white
    }
    
    var linkColor: NSColor {
        if let data = defaults.data(forKey: Constants.Defaults.linkColor),
           let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data) {
            return color
        }
        return .blue
    }
    
    var selectionColor: NSColor {
        if let data = defaults.data(forKey: Constants.Defaults.selectionColor),
           let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data) {
            return color
        }
        return .selectedTextBackgroundColor
    }
}

