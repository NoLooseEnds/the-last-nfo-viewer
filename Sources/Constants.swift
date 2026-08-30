import Foundation

enum PreferenceChange: String, CaseIterable {
    case appearance
    case contentMetrics
    case contentPresentation
    case windowSizing
    case copyFormat

    private static let userInfoKey = "changes"

    static func userInfo(for changes: Set<PreferenceChange>) -> [AnyHashable: Any] {
        [userInfoKey: changes.map(\.rawValue)]
    }

    static func changes(from notification: Notification) -> Set<PreferenceChange> {
        guard let rawValues = notification.userInfo?[userInfoKey] as? [String] else {
            return Set(allCases)
        }

        return Set(rawValues.compactMap(PreferenceChange.init(rawValue:)))
    }
}

struct Constants {
    struct FontSize {
        static let defaultValue = 14.0
        static let minimum = 8.0
        static let maximum = 72.0

        static func normalized(_ storedValue: Double) -> Double {
            guard storedValue.isFinite, storedValue > 0 else { return defaultValue }
            return min(max(storedValue, minimum), maximum)
        }
    }

    struct Defaults {
        static let fontName = "fontName"
        static let fontSize = "fontSize"
        static let highlightLinks = "highlightLinks"
        static let appearanceMode = "appearanceMode"
        static let textAlignment = "textAlignment"
        static let copyFormat = "copyFormat"
        static let autoFitWindowSize = "autoFitWindowSize"
        static let legacyAutoFitWindowWidth = "autoFitWindowWidth"
        
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
