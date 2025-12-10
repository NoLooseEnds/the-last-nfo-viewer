import Foundation

struct Constants {
    struct Defaults {
        static let fontName = "fontName"
        static let fontSize = "fontSize"
        static let highlightLinks = "highlightLinks"
        static let appearanceMode = "appearanceMode"
        static let textAlignment = "textAlignment"
        static let copyFormat = "copyFormat"
        
        static let textColor = "textColor"
        static let backgroundColor = "backgroundColor"
        static let linkColor = "linkColor"
        static let selectionColor = "selectionColor"
    }
    
    struct Notifications {
        static let themeChanged = Notification.Name("ThemeChanged")
        static let preferencesChanged = Notification.Name("PreferencesChanged")
    }
}

