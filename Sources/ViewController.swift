import Cocoa
import UniformTypeIdentifiers
import CoreText

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
    private let exportPadding: CGFloat = 20.0
    
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
        let padding = self.exportPadding
        contentRect.size.width += padding * 2
        contentRect.size.height += padding * 2
        
        // 2. Create image using block-based API to support flipped coordinates
        let image = NSImage(size: contentRect.size, flipped: true) { rect in
            // 3. Draw background
            let backgroundColor = ThemeManager.shared.backgroundColor
            backgroundColor.setFill()
            NSBezierPath(rect: rect).fill()
            
            // 4. Draw text
            // Offset by padding
            let origin = NSPoint(x: padding, y: padding)
            let glyphRange = layoutManager.glyphRange(for: textContainer)
            layoutManager.drawBackground(forGlyphRange: glyphRange, at: origin)
            layoutManager.drawGlyphs(forGlyphRange: glyphRange, at: origin)
            
            return true
        }
        
        return image
    }
    
    @objc func copyAsImage(_ sender: Any?) {
        // Standard action: Use preferred format
        let copyFormat = UserDefaults.standard.string(forKey: Constants.Defaults.copyFormat) ?? "png"
        let preferSVG = copyFormat == "svg"
        
        performCopy(asSVG: preferSVG)
    }
    
    @objc func copyAsAlternateImage(_ sender: Any?) {
        // Alternate action: Use the OTHER format
        let copyFormat = UserDefaults.standard.string(forKey: Constants.Defaults.copyFormat) ?? "png"
        let preferSVG = copyFormat == "svg"
        
        // If preferred is SVG, alternate is PNG (so asSVG = false)
        // If preferred is PNG, alternate is SVG (so asSVG = true)
        performCopy(asSVG: !preferSVG)
    }
    
    private func performCopy(asSVG: Bool) {
        if asSVG {
            guard let svgContent = generateSVG() else { return }
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(svgContent, forType: .string)
            showNotificationPopup(text: "Copied as SVG")
        } else {
            guard let image = generateImage() else { return }
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.writeObjects([image])
            showNotificationPopup(text: "Copied as PNG")
        }
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
    
    @objc func exportFile(_ sender: Any?) {
        let savePanel = NSSavePanel()
        
        // Setup accessory view for format selection
        let accessoryView = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: 40))
        let formatPopup = NSPopUpButton(frame: NSRect(x: 60, y: 10, width: 100, height: 24))
        formatPopup.addItems(withTitles: ["PNG", "SVG"])
        
        let label = NSTextField(labelWithString: "Format:")
        label.frame = NSRect(x: 0, y: 12, width: 55, height: 20)
        label.alignment = .right
        
        accessoryView.addSubview(label)
        accessoryView.addSubview(formatPopup)
        
        savePanel.accessoryView = accessoryView
        savePanel.canCreateDirectories = true
        savePanel.isExtensionHidden = false
        
        // Set initial state
        let copyFormat = UserDefaults.standard.string(forKey: Constants.Defaults.copyFormat) ?? "png"
        if copyFormat == "svg" {
            formatPopup.selectItem(withTitle: "SVG")
            savePanel.allowedFileTypes = ["svg"]
        } else {
            formatPopup.selectItem(withTitle: "PNG")
            savePanel.allowedFileTypes = ["png"]
        }
        
        savePanel.nameFieldStringValue = (self.view.window?.title ?? "Export")
        
        // Handle format change in save panel
        // Note: NSSavePanel doesn't easily support dynamic extension changes via accessory view events in a simple way
        // without subclassing or delegate. But we can simply rely on the user checking the dropdown.
        // Actually, updating the allowedFileTypes while the panel is open is tricky.
        // A simpler approach for the user: Just have the dropdown set the extension?
        // Let's attach an action to the popup to update the allowed types and name field.
        
        formatPopup.target = self
        formatPopup.action = #selector(exportFormatChanged(_:))
        // We need to store reference to savePanel to update it, but we can't easily pass it.
        // Helper object? Or just use associated object / tag?
        // Let's use a simpler approach: "Export as..." with a format selector.
        
        // Actually, standard macOS apps often put the format selector in the accessory view and update the panel.
        // Let's try to update the panel from the action. We can associate the panel with the popup.
        objc_setAssociatedObject(formatPopup, "savePanel", savePanel, .OBJC_ASSOCIATION_ASSIGN)
        
        savePanel.beginSheetModal(for: self.view.window!) { response in
            if response == .OK, let url = savePanel.url {
                let selectedFormat = formatPopup.selectedItem?.title ?? "PNG"
                if selectedFormat == "SVG" {
                    if let svgContent = self.generateSVG() {
                        try? svgContent.write(to: url, atomically: true, encoding: .utf8)
                    }
                } else {
                    if let image = self.generateImage(),
                       let tiffData = image.tiffRepresentation,
                       let bitmapRep = NSBitmapImageRep(data: tiffData),
                       let pngData = bitmapRep.representation(using: .png, properties: [:]) {
                        try? pngData.write(to: url)
                    }
                }
            }
        }
    }
    
    @objc func exportFormatChanged(_ sender: NSPopUpButton) {
        guard let savePanel = objc_getAssociatedObject(sender, "savePanel") as? NSSavePanel else { return }
        let format = sender.selectedItem?.title.lowercased() ?? "png"
        savePanel.allowedFileTypes = [format]
        
        // Update name field extension
        let currentName = savePanel.nameFieldStringValue
        let newName = (currentName as NSString).deletingPathExtension + "." + format
        savePanel.nameFieldStringValue = newName
    }
    
    private func generateSVG() -> String? {
        guard let textStorage = textView.textStorage else { return nil }
        
        let fullString = textStorage.string as NSString
        let length = fullString.length
        
        if length == 0 { return nil }
        
        // Font metrics
        let font = textStorage.attribute(.font, at: 0, effectiveRange: nil) as? NSFont ?? NSFont.userFixedPitchFont(ofSize: 12) ?? NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        let ctFont = font as CTFont
        let ascent = CTFontGetAscent(ctFont)
        let descent = CTFontGetDescent(ctFont)
        let leading = CTFontGetLeading(ctFont)
        let lineHeight = ascent + descent + leading
        
        let padding = self.exportPadding
        
        // Pre-calculate dimensions to set SVG size
        var maxWidth: CGFloat = 0
        var lineCount: Int = 0
        
        fullString.enumerateSubstrings(in: NSRange(location: 0, length: length), options: .byLines) { (substring, substringRange, enclosingRange, stop) in
            lineCount += 1
            if let substring = substring {
                let attrString = NSAttributedString(string: substring, attributes: [.font: font])
                let line = CTLineCreateWithAttributedString(attrString)
                let lineWidth = CTLineGetTypographicBounds(line, nil, nil, nil)
                if lineWidth > maxWidth {
                    maxWidth = lineWidth
                }
            }
        }
        
        let width = Int(ceil(maxWidth + padding * 2))
        let height = Int(ceil(CGFloat(lineCount) * lineHeight + padding * 2))
        
        let bgHex = hexString(from: ThemeManager.shared.backgroundColor)
        let defaultColor = ThemeManager.shared.textColor
        let defaultFillHex = hexString(from: defaultColor)
        
        var svg = """
        <svg xmlns="http://www.w3.org/2000/svg" width="\(width)" height="\(height)" viewBox="0 0 \(width) \(height)">
        <rect width="100%" height="100%" fill="\(bgHex)"/>
        """
        
        // Render lines
        var currentLineIndex = 0
        
        fullString.enumerateSubstrings(in: NSRange(location: 0, length: length), options: .byLines) { (substring, substringRange, enclosingRange, stop) in
            guard let substring = substring else {
                currentLineIndex += 1
                return
            }
            
            // We need to preserve attributes from the original storage (e.g. colors)
            // But we must be careful: textStorage attributes map to the original range.
            let attrString = textStorage.attributedSubstring(from: substringRange)
            
            // Fallback font if not set (should be set though)
            let lineAttrString = NSMutableAttributedString(attributedString: attrString)
            if lineAttrString.length > 0 && lineAttrString.attribute(.font, at: 0, effectiveRange: nil) == nil {
                lineAttrString.addAttribute(.font, value: font, range: NSRange(location: 0, length: lineAttrString.length))
            }
            
            let line = CTLineCreateWithAttributedString(lineAttrString)
            let runs = CTLineGetGlyphRuns(line) as! [CTRun]
            
            // Calculate Y position for the baseline of this line
            // SVG Y starts at 0 (top).
            // Line 0 baseline is at: padding + ascent.
            // Line 1 baseline is at: padding + ascent + lineHeight.
            let lineBaselineY = padding + ascent + (CGFloat(currentLineIndex) * lineHeight)
            
            for run in runs {
                let attributes = CTRunGetAttributes(run) as NSDictionary
                let runFont = attributes[kCTFontAttributeName as String] as! CTFont
                let runCount = CTRunGetGlyphCount(run)
                
                // Get Color for this run
                let runColor = (attributes[NSAttributedString.Key.foregroundColor] as? NSColor) ?? defaultColor
                let fillHex = self.hexString(from: runColor)
                
                for i in 0..<runCount {
                    let glyphRange = CFRangeMake(i, 1)
                    var glyph = CGGlyph()
                    var position = CGPoint()
                    
                    CTRunGetGlyphs(run, glyphRange, &glyph)
                    CTRunGetPositions(run, glyphRange, &position)
                    
                    if let path = CTFontCreatePathForGlyph(runFont, glyph, nil) {
                        // Transform:
                        // 1. Flip Y (CoreText path is y-up).
                        // 2. Translate X to (padding + position.x).
                        // 3. Translate Y to lineBaselineY.
                        // Note: position.y is usually 0 relative to the baseline for horizontal text,
                        // but can be non-zero for offsets.
                        
                        // Matrix logic:
                        // x' = x + (padding + position.x)
                        // y' = -y + (lineBaselineY - position.y)
                        // Wait, if y is flipped, -y means UP in SVG coords? No.
                        // SVG coords: +y is DOWN.
                        // CoreText path: +y is UP from baseline.
                        // So a point (0, 10) in font [10 units above baseline] should be at (baselineY - 10) in SVG.
                        // y_svg = lineBaselineY - y_font
                        // y_svg = lineBaselineY + (-1 * y_font)
                        // So scaling y by -1 is correct.
                        // And translation ty should be lineBaselineY.
                        
                        // Let's verify position.y. Usually 0. If it's 5 (superscript), we want it 5 units higher visually.
                        // Higher visually means SMALLER y in SVG.
                        // y_svg = lineBaselineY - (y_font + position.y)
                        // y_svg = lineBaselineY - position.y - y_font
                        
                        let finalX = padding + position.x
                        let finalY = lineBaselineY - position.y
                        
                        var transform = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: finalX, ty: finalY)
                        
                        if let transformedPath = path.copy(using: &transform) {
                            let pathData = transformedPath.svgPath
                            if !pathData.isEmpty {
                                svg += "<path d=\"\(pathData)\" fill=\"\(fillHex)\"/>\n"
                            }
                        }
                    }
                }
            }
            
            currentLineIndex += 1
        }
        
        svg += "</svg>"
        return svg
    }
    
    private func hexString(from color: NSColor) -> String {
        guard let rgbColor = color.usingColorSpace(.sRGB) else { return "#000000" }
        let r = Int(round(rgbColor.redComponent * 255))
        let g = Int(round(rgbColor.greenComponent * 255))
        let b = Int(round(rgbColor.blueComponent * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }
    
    private func escapeXML(_ string: String) -> String {
        return string.replacingOccurrences(of: "&", with: "&amp;")
                     .replacingOccurrences(of: "<", with: "&lt;")
                     .replacingOccurrences(of: ">", with: "&gt;")
                     .replacingOccurrences(of: "\"", with: "&quot;")
                     .replacingOccurrences(of: "'", with: "&apos;")
    }
}

extension CGPath {
    var svgPath: String {
        class PathInfo {
            var string = ""
        }
        
        let info = PathInfo()
        
        // Ensure we use a locale that uses dot as decimal separator
        let locale = Locale(identifier: "en_US")
        
        self.apply(info: UnsafeMutableRawPointer(Unmanaged.passUnretained(info).toOpaque())) { (info, elementPointer) in
            let infoObj = Unmanaged<PathInfo>.fromOpaque(info!).takeUnretainedValue()
            let element = elementPointer.pointee
            let points = element.points
            
            // Helper for locale-aware formatting
            func fmt(_ val: CGFloat) -> String {
                return String(format: "%.2f", locale: Locale(identifier: "en_US"), val)
            }
            
            switch element.type {
            case .moveToPoint:
                infoObj.string += "M\(fmt(points[0].x)),\(fmt(points[0].y)) "
            case .addLineToPoint:
                infoObj.string += "L\(fmt(points[0].x)),\(fmt(points[0].y)) "
            case .addQuadCurveToPoint:
                infoObj.string += "Q\(fmt(points[0].x)),\(fmt(points[0].y)) \(fmt(points[1].x)),\(fmt(points[1].y)) "
            case .addCurveToPoint:
                infoObj.string += "C\(fmt(points[0].x)),\(fmt(points[0].y)) \(fmt(points[1].x)),\(fmt(points[1].y)) \(fmt(points[2].x)),\(fmt(points[2].y)) "
            case .closeSubpath:
                infoObj.string += "Z "
            @unknown default:
                break
            }
        }
        
        return info.string.trimmingCharacters(in: .whitespaces)
    }
}

