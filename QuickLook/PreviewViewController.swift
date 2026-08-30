import Cocoa
import Quartz

class PreviewViewController: NSViewController, QLPreviewingController {
    private static let distributedPreferencesChanged = Notification.Name(
        "com.nle.TheLastNFOViewer.preferencesChanged"
    )
    private static let linkDetector: NSDataDetector? = {
        try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
    }()
    
    private var textView: NSTextView!
    private var contentWidth: CGFloat = 0
    private var contentHeight: CGFloat = 0
    
    private var sharedConfig: [String: Any] = [:]
    
    override func loadView() {
        loadSharedConfig()
        
        let scrollView = NSScrollView()
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        
        let contentSize = NSSize(width: 800, height: 600)
        scrollView.frame = NSRect(origin: .zero, size: contentSize)
        
        textView = NSTextView(frame: NSRect(origin: .zero, size: contentSize))
        textView.minSize = .zero
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = true
        textView.autoresizingMask = [.width]
        
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.lineBreakMode = .byClipping
        
        textView.isEditable = false
        textView.isSelectable = true
        
        scrollView.documentView = textView
        self.view = scrollView
        
        updateAppearance()
        
        DistributedNotificationCenter.default.addObserver(
            self,
            selector: #selector(themeChanged),
            name: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil
        )
        DistributedNotificationCenter.default.addObserver(
            self,
            selector: #selector(sharedPreferencesChanged),
            name: Self.distributedPreferencesChanged,
            object: nil
        )
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        alignContent()
    }
    
    deinit {
        DistributedNotificationCenter.default.removeObserver(self)
    }
    
    @objc private func themeChanged() {
        updateText(textView.string)
    }

    @objc private func sharedPreferencesChanged() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.loadSharedConfig()
            self.updateText(self.textView.string)
        }
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
        
        let textColor = resolvedColor(
            configKey: "textColor",
            customFlagKey: "hasCustomTextColor",
            fallback: isEffectiveDark ? .white : .black
        )
        let backgroundColor = resolvedColor(
            configKey: "backgroundColor",
            customFlagKey: "hasCustomBackgroundColor",
            fallback: isEffectiveDark ? .black : .white
        )
        let linkColor = resolvedColor(
            configKey: "linkColor",
            customFlagKey: "hasCustomLinkColor",
            fallback: .blue
        )
        let selectionColor = resolvedColor(
            configKey: "selectionColor",
            customFlagKey: "hasCustomSelectionColor",
            fallback: .selectedTextBackgroundColor
        )

        textView.textColor = textColor
        textView.backgroundColor = backgroundColor
        textView.linkTextAttributes = [
            .foregroundColor: linkColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .cursor: NSCursor.pointingHand
        ]
        textView.selectedTextAttributes = [.backgroundColor: selectionColor]
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

    private func resolvedColor(
        configKey: String,
        customFlagKey: String,
        fallback: NSColor
    ) -> NSColor {
        if sharedConfig[customFlagKey] as? Bool == false {
            return fallback
        }
        if let hex = sharedConfig[configKey] as? String {
            return color(from: hex)
        }
        return fallback
    }
    
    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        registerFont()
        
        do {
            let startAccess = url.startAccessingSecurityScopedResource()
            defer { if startAccess { url.stopAccessingSecurityScopedResource() } }
            
            let data = try Data(contentsOf: url)
            let content = try NFOContentDecoder.decode(data)

            DispatchQueue.main.async {
                self.updateText(content)
                handler(nil)
            }
        } catch {
            handler(error)
        }
    }
    
    private func registerFont() {
        let bundle = Bundle(for: type(of: self))
        var urls = bundle.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? []
        urls.append(contentsOf: bundle.urls(
            forResourcesWithExtension: "ttf",
            subdirectory: "Fonts"
        ) ?? [])

        if !urls.isEmpty {
            CTFontManagerRegisterFontURLs(urls as CFArray, .process, true, nil)
        }
    }
    
    private func getRealHomeDirectory() -> URL? {
        if let pw = getpwuid(getuid()), let homeDir = String(validatingUTF8: pw.pointee.pw_dir) {
            return URL(fileURLWithPath: homeDir)
        }
        return nil
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
        let configuredFontSize = (sharedConfig["fontSize"] as? Double) ?? 14.0
        let fontSize = configuredFontSize.isFinite && configuredFontSize > 0
            ? min(max(configuredFontSize, 8.0), 72.0)
            : 14.0
        let fontName = (sharedConfig["fontName"] as? String) ?? "More Perfect DOS VGA"
        
        let font = NSFont(name: fontName, size: fontSize)
            ?? NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)

        let textColor = resolvedTextColor()
        let attributedString = NSMutableAttributedString(
            string: content,
            attributes: [.font: font, .foregroundColor: textColor]
        )
        if sharedConfig["highlightLinks"] as? Bool == true,
           let detector = Self.linkDetector {
            let fullRange = NSRange(location: 0, length: content.utf16.count)
            let linkColor = resolvedLinkColor()
            for match in detector.matches(in: content, options: [], range: fullRange) {
                if let url = match.url {
                    attributedString.addAttributes([
                        .link: url,
                        .foregroundColor: linkColor,
                        .underlineStyle: NSUnderlineStyle.single.rawValue
                    ], range: match.range)
                }
            }
        }
        textView.textStorage?.setAttributedString(attributedString)

        let measuredSize = attributedString.size()
        contentWidth = measuredSize.width
        contentHeight = measuredSize.height
        updatePreferredContentSize()
        alignContent()
        updateAppearance()
    }

    private func resolvedTextColor() -> NSColor {
        let mode = (sharedConfig["appearanceMode"] as? String) ?? "System"
        let isDark: Bool
        switch mode {
        case "Dark": isDark = true
        case "Light": isDark = false
        default:
            isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        }
        return resolvedColor(
            configKey: "textColor",
            customFlagKey: "hasCustomTextColor",
            fallback: isDark ? .white : .black
        )
    }

    private func resolvedLinkColor() -> NSColor {
        resolvedColor(
            configKey: "linkColor",
            customFlagKey: "hasCustomLinkColor",
            fallback: .blue
        )
    }

    private func alignContent() {
        guard let scrollView = view as? NSScrollView,
              let textContainer = textView.textContainer else { return }

        let alignment: NFOTextAlignment
        switch (sharedConfig["textAlignment"] as? String) ?? "Center" {
        case "Left": alignment = .left
        case "Right": alignment = .right
        default: alignment = .center
        }
        let layout = NFOLayoutPolicy.contentLayout(
            contentWidth: contentWidth,
            availableWidth: scrollView.contentSize.width,
            alignment: alignment
        )

        textView.isHorizontallyResizable = layout.scrollsHorizontally
        textView.autoresizingMask = layout.scrollsHorizontally ? [] : [.width]
        textContainer.widthTracksTextView = layout.widthTracksTextView
        textView.textContainerInset = NSSize(
            width: layout.horizontalInset,
            height: 0
        )

        if let containerWidth = layout.textContainerWidth,
           !layout.widthTracksTextView {
            textContainer.containerSize = NSSize(
                width: containerWidth,
                height: CGFloat.greatestFiniteMagnitude
            )
        }
        let targetHeight = max(
            scrollView.contentSize.height,
            ceil(contentHeight)
        )
        let targetSize = NSSize(width: layout.textViewWidth, height: targetHeight)
        if textView.frame.size != targetSize {
            textView.setFrameSize(targetSize)
        }
    }

    private func updatePreferredContentSize() {
        guard let screen = view.window?.screen ?? NSScreen.main else { return }

        let idealSize = NSSize(
            width: contentWidth + NFOLayoutPolicy.horizontalWindowPadding,
            height: contentHeight + NFOLayoutPolicy.verticalWindowPadding
        )
        preferredContentSize = NFOLayoutPolicy.autoFitSize(
            idealSize: idealSize,
            visibleSize: screen.visibleFrame.size
        )
    }
}
