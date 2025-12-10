import Cocoa

class ViewController: NSViewController {
    
    // Optimized: Reusable detector to avoid expensive recreation
    private static let linkDetector: NSDataDetector? = {
        try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
    }()

    var textContent: String = "" {
        didSet {
            updateText()
        }
    }
    
    private var textView: NSTextView!
    private var cachedContentWidth: CGFloat = 0
    
    override func loadView() {
        let scrollView = ThemeAwareScrollView()
        scrollView.onAppearanceChanged = { [weak self] in
            self?.handleAppearanceChange()
        }
        
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        
        // Initial size
        let contentSize = NSSize(width: 800, height: 600)
        scrollView.frame = NSRect(origin: .zero, size: contentSize)
        
        textView = NSTextView()
        textView.minSize = NSSize(width: 0, height: contentSize.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = true // Ensure it can grow wide
        textView.autoresizingMask = [.width, .height]
        
        // NFO viewing settings: no wrapping
        // CRITICAL: Set widthTracksTextView to true if we want to fill space, 
        // but false if we want horizontal scroll.
        // If we want centering, we usually need widthTracksTextView = false so container is just content size?
        // No, for centering logic above (using insets), we typically have widthTracksTextView = true 
        // so the text view fills the scroll view, and we use insets to push text to center.
        // BUT, for NFOs that are WIDER than window, we MUST have horizontal scroll.
        // If widthTracksTextView = true, text wraps (unless line break mode is char wrap? no).
        // To enable horizontal scrolling for non-wrapping text, widthTracksTextView usually must be false
        // OR the container size must be huge.
        // 
        // Let's fix the horizontal scrollbar issue:
        // "there is always a horisontal scrollbar" -> This means content size > view size always?
        // Or container size is huge.
        //
        // If we use "widthTracksTextView = true", we lose horizontal scrolling if text is wider than view 
        // (it just clips or wraps).
        // If we use "widthTracksTextView = false" (current), the text container size is huge (greatestFiniteMagnitude).
        // This causes the horizontal scrollbar to appear because the document view is huge.
        //
        // FIX: We need to resize the TextContainer to fit the content width exactly (plus padding), 
        // but ensure it's at least the ScrollView width (for background color filling).
        
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.lineFragmentPadding = 0 // Remove extra padding to simplify width calculations
        textView.textContainer?.lineBreakMode = .byClipping // Prevent wrapping
        
        textView.backgroundColor = .white
        textView.textColor = .black
        textView.isEditable = false
        textView.isSelectable = true
        
        scrollView.documentView = textView
        
        self.view = scrollView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Listen for theme changes
        NotificationCenter.default.addObserver(self, selector: #selector(applyTheme), name: Constants.Notifications.themeChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(applyTheme), name: Constants.Notifications.preferencesChanged, object: nil)
        
        applyTheme()
        updateText()
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        // Ensure theme is applied to window now that it exists
        applyTheme()
    }
    
    @objc private func applyTheme() {
        // Apply appearance to window
        let targetWindow = view.window ?? NSApp.windows.first
        ThemeManager.shared.applyAppearance(to: targetWindow)
        
        // Update TextView colors from Manager
        textView.backgroundColor = ThemeManager.shared.backgroundColor
        textView.textColor = ThemeManager.shared.textColor
        
        // Re-render text to apply correct color attributes
        updateText()
    }
    
    // Called when system appearance changes
    func handleAppearanceChange() {
        if ThemeManager.shared.currentMode == .system {
            applyTheme()
        }
    }
    
    @objc func toggleDarkMode() {
        ThemeManager.shared.toggleDarkMode()
    }
    
    @objc func increaseFontSize() {
        ThemeManager.shared.increaseFontSize()
    }
    
    @objc func decreaseFontSize() {
        ThemeManager.shared.decreaseFontSize()
    }
    
    @objc func resetFontSize() {
        ThemeManager.shared.resetFontSize()
    }
    
    private func updateText() {
        guard let textView = textView else { return }
        let defaults = UserDefaults.standard
        
        // Font setup
        let fontName = defaults.string(forKey: Constants.Defaults.fontName) ?? "More Perfect DOS VGA"
        let fontSize = defaults.double(forKey: Constants.Defaults.fontSize) > 0 ? defaults.double(forKey: Constants.Defaults.fontSize) : 14.0
        
        let font = NSFont(name: fontName, size: fontSize) ?? NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        
        // Colors from Manager
        let textColor = ThemeManager.shared.textColor
        let linkColor = ThemeManager.shared.linkColor
        let selectionColor = ThemeManager.shared.selectionColor
        
        textView.selectedTextAttributes = [.backgroundColor: selectionColor]
        
        // Prepare string
        let content = textContent
        let attributedString = NSMutableAttributedString(string: content)
        let fullRange = NSRange(location: 0, length: content.utf16.count)
        
        // Base attributes
        attributedString.addAttributes([
            .font: font,
            .foregroundColor: textColor
        ], range: fullRange)
        
        // Set basic content immediately
        if let textStorage = textView.textStorage {
            textStorage.setAttributedString(attributedString)
        }
        
        // Link detection (async)
        if defaults.bool(forKey: Constants.Defaults.highlightLinks) {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }
                guard let detector = ViewController.linkDetector else { return }
                
                let matches = detector.matches(in: content, options: [], range: fullRange)
                
                if !matches.isEmpty {
                    DispatchQueue.main.async {
                        // Check if content has changed while we were processing
                        guard self.textContent == content else { return }
                        
                        if let textStorage = self.textView.textStorage {
                            textStorage.beginEditing()
                            for match in matches {
                                if let url = match.url {
                                    textStorage.addAttributes([
                                        .link: url,
                                        .foregroundColor: linkColor,
                                        .underlineStyle: NSUnderlineStyle.single.rawValue
                                    ], range: match.range)
                                }
                            }
                            textStorage.endEditing()
                        }
                    }
                }
            }
        }
        
        // Preserve scroll position
        let visibleRect = textView.visibleRect
        
        // Measure content width with unconstrained container
        if let layoutManager = textView.layoutManager, let textContainer = textView.textContainer {
            // Temporarily ensure container is huge to get true unwrapped width
            // We must set widthTracksTextView to false to allow manual resizing
            textContainer.widthTracksTextView = false
            let oldSize = textContainer.containerSize
            textContainer.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
            layoutManager.ensureLayout(for: textContainer)
            cachedContentWidth = layoutManager.usedRect(for: textContainer).width
            // We will restore/adjust size in centerContent
        }
        
        // Update centering
        centerContent()
        
        textView.scroll(visibleRect.origin)
    }
    
    override func viewDidLayout() {
        super.viewDidLayout()
        centerContent()
    }

    private func centerContent() {
        guard let textContainer = textView.textContainer,
              let scrollView = self.view as? NSScrollView else { return }
        
        // Use cached content width to avoid layout dependency loops
        let contentWidth = cachedContentWidth
        
        let availableWidth = scrollView.contentSize.width
        let minPadding: CGFloat = 20.0
        let totalMinPadding = minPadding * 2
        
        let align = UserDefaults.standard.string(forKey: Constants.Defaults.textAlignment) ?? "Center"
        
        var insetWidth: CGFloat = minPadding
        var targetContainerWidth: CGFloat = 0
        
        // Logic:
        // We want the text container to be at least (content + padding).
        // If window is wider, we extend the container to window width and use insets to align.
        
        let requiredContentWidth = contentWidth + totalMinPadding
        
        if availableWidth > requiredContentWidth {
            // Window is wider than content -> Center/Align
            
            // Enable autoresizing for width so it tracks window resize (and vertical scrollbar appearance)
            textView.autoresizingMask = [.width, .height]
            textContainer.widthTracksTextView = true
            
            targetContainerWidth = availableWidth
            
            if align == "Center" || align == "Right" {
                // Center logic (Right aligned handled as center for now)
                insetWidth = floor((availableWidth - contentWidth) / 2)
            } else {
                // Left
                insetWidth = minPadding
            }
        } else {
            // Content is wider -> Scroll
            
            // Disable autoresizing to prevent wrapping/reflow and allow horizontal scrolling
            textView.autoresizingMask = [.height]
            textContainer.widthTracksTextView = false
            
            targetContainerWidth = requiredContentWidth
            insetWidth = minPadding
        }
        
        // Apply updates
        if textView.textContainerInset.width != insetWidth {
            textView.textContainerInset = NSSize(width: insetWidth, height: 0)
        }
        
        // When widthTracksTextView is true, setting containerSize.width is ignored/overwritten by textView width,
        // but we set it for the 'else' case.
        if !textContainer.widthTracksTextView {
            if textContainer.containerSize.width != targetContainerWidth {
                textContainer.containerSize = NSSize(width: targetContainerWidth, height: CGFloat.greatestFiniteMagnitude)
            }
        }
        
        // Update frame size
        // If autoresizing is ON, this sets the initial size and then system maintains it.
        // If autoresizing is OFF, this sets the fixed size.
        if textView.frame.width != targetContainerWidth {
             textView.setFrameSize(NSSize(width: targetContainerWidth, height: textView.frame.height))
        }
        
        // Force display to ensure visual update
        textView.needsDisplay = true
    }
    
    // Calculate ideal content width based on current text and font
    func calculateIdealContentWidth() -> CGFloat {
        // Return cached width + padding
        return cachedContentWidth + 60 // 20+20 padding + 20 extra safety
    }
    
    // MARK: - Image Export
    
    func generateImage() -> NSImage? {
        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer,
              let textStorage = textView.textStorage else { return nil }
        
        // 1. Calculate the bounding rect of all text
        // Ensure layout is up to date
        layoutManager.ensureLayout(for: textContainer)
        var contentRect = layoutManager.usedRect(for: textContainer)
        
        // Add padding
        let padding: CGFloat = 20.0
        contentRect.size.width += padding * 2
        contentRect.size.height += padding * 2
        
        // 2. Create image
        let image = NSImage(size: contentRect.size)
        
        image.lockFocus()
        
        // 3. Draw background
        let backgroundColor = ThemeManager.shared.backgroundColor
        backgroundColor.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: contentRect.size)).fill()
        
        // 4. Draw text
        // Offset by padding
        let origin = NSPoint(x: padding, y: padding)
        let glyphRange = layoutManager.glyphRange(for: textContainer)
        layoutManager.drawBackground(forGlyphRange: glyphRange, at: origin)
        layoutManager.drawGlyphs(forGlyphRange: glyphRange, at: origin)
        
        image.unlockFocus()
        
        return image
    }
    
    @objc func copyAsImage(_ sender: Any?) {
        guard let image = generateImage() else { return }
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
        
        showNotificationPopup(text: "Copied as Image")
    }
    
    private func showNotificationPopup(text: String) {
        let hudView = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: 50))
        hudView.wantsLayer = true
        hudView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.75).cgColor
        hudView.layer?.cornerRadius = 10
        
        let textField = NSTextField(labelWithString: text)
        textField.textColor = .white
        textField.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        textField.alignment = .center
        textField.translatesAutoresizingMaskIntoConstraints = false
        
        hudView.addSubview(textField)
        
        NSLayoutConstraint.activate([
            textField.centerXAnchor.constraint(equalTo: hudView.centerXAnchor),
            textField.centerYAnchor.constraint(equalTo: hudView.centerYAnchor)
        ])
        
        // Center in window
        guard let windowView = self.view.window?.contentView else { return }
        hudView.frame.origin = CGPoint(
            x: (windowView.bounds.width - hudView.frame.width) / 2,
            y: (windowView.bounds.height - hudView.frame.height) / 2
        )
        
        windowView.addSubview(hudView)
        
        // Animation
        hudView.alphaValue = 0
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            hudView.animator().alphaValue = 1
        }, completionHandler: {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = 0.5
                    hudView.animator().alphaValue = 0
                }, completionHandler: {
                    hudView.removeFromSuperview()
                })
            }
        })
    }
    
    @objc func exportAsImage(_ sender: Any?) {
        guard let image = generateImage(),
              let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRep.representation(using: .png, properties: [:]) else { return }
        
        let savePanel = NSSavePanel()
        if #available(macOS 11.0, *) {
            savePanel.allowedContentTypes = [.png]
        } else {
            savePanel.allowedFileTypes = ["png"]
        }
        savePanel.canCreateDirectories = true
        savePanel.isExtensionHidden = false
        savePanel.nameFieldStringValue = (self.view.window?.title ?? "Export") + ".png"
        
        savePanel.beginSheetModal(for: self.view.window!) { response in
            if response == .OK, let url = savePanel.url {
                try? pngData.write(to: url)
            }
        }
    }
}

