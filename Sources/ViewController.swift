import Cocoa
import UniformTypeIdentifiers
import CoreText

class ViewController: NSViewController {
    
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
    private var cachedContentHeight: CGFloat = 0
    private var textRenderGeneration: UInt = 0
    private let exportPadding: CGFloat = 20.0
    private weak var activeSavePanel: NSSavePanel?
    
    override func loadView() {
        let scrollView = ThemeAwareScrollView()
        scrollView.onAppearanceChanged = { [weak self] in
            self?.handleAppearanceChange()
        }
        
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        
        let contentSize = NSSize(width: 800, height: 600)
        scrollView.frame = NSRect(origin: .zero, size: contentSize)
        
        textView = NSTextView()
        textView.minSize = NSSize(width: 0, height: contentSize.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = true
        textView.autoresizingMask = [.width, .height]
        
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.lineBreakMode = .byClipping
        
        textView.backgroundColor = .white
        textView.textColor = .black
        textView.isEditable = false
        textView.isSelectable = true
        
        scrollView.documentView = textView
        
        self.view = scrollView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(self, selector: #selector(applyTheme), name: Constants.Notifications.themeChanged, object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(preferencesDidChange(_:)),
            name: Constants.Notifications.preferencesChanged,
            object: nil
        )
        
        applyTheme()
        updateText()
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        applyTheme()
    }
    
    @objc private func applyTheme() {
        ThemeManager.shared.applyAppearance(to: view.window)
        
        // Update TextView colors from Manager
        textView.backgroundColor = ThemeManager.shared.backgroundColor
        textView.textColor = ThemeManager.shared.textColor
        
        // Re-render text to apply correct color attributes
        updateText()
    }

    @objc private func preferencesDidChange(_ notification: Notification) {
        let changes = PreferenceChange.changes(from: notification)
        if changes.contains(.appearance) {
            applyTheme()
        } else if changes.contains(.contentMetrics) || changes.contains(.contentPresentation) {
            updateText()
        }
    }
    
    // Called when system appearance changes
    func handleAppearanceChange() {
        if ThemeManager.shared.currentMode == .system {
            applyTheme()
        }
    }
    
    private func updateText() {
        guard let textView = textView else { return }
        textRenderGeneration &+= 1
        let renderGeneration = textRenderGeneration
        let defaults = UserDefaults.standard
        
        // Font setup
        let fontName = defaults.string(forKey: Constants.Defaults.fontName) ?? "More Perfect DOS VGA"
        let fontSize = Constants.FontSize.normalized(
            defaults.double(forKey: Constants.Defaults.fontSize)
        )
        
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
            DispatchQueue.global(qos: .userInitiated).async {
                guard let detector = ViewController.linkDetector else { return }
                
                let matches = detector.matches(in: content, options: [], range: fullRange)
                
                if !matches.isEmpty {
                    DispatchQueue.main.async { [weak self] in
                        guard let self,
                              self.textRenderGeneration == renderGeneration,
                              self.textContent == content,
                              UserDefaults.standard.bool(forKey: Constants.Defaults.highlightLinks) else {
                            return
                        }
                        
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
        
        // Measure independently of the text container's current alignment/layout state.
        // NSLayoutManager.usedRect can report the artificial maximum container width
        // after a right-aligned view is rendered a second time.
        let measuredSize = attributedString.size()
        cachedContentWidth = measuredSize.width
        cachedContentHeight = measuredSize.height
        
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
        
        let availableWidth = scrollView.contentSize.width
        let alignment: NFOTextAlignment
        switch UserDefaults.standard.string(forKey: Constants.Defaults.textAlignment) ?? "Center" {
        case "Left": alignment = .left
        case "Right": alignment = .right
        default: alignment = .center
        }
        let layout = NFOLayoutPolicy.contentLayout(
            contentWidth: cachedContentWidth,
            availableWidth: availableWidth,
            alignment: alignment
        )

        textView.isHorizontallyResizable = layout.scrollsHorizontally
        textView.autoresizingMask = layout.scrollsHorizontally ? [.height] : [.width, .height]
        textContainer.widthTracksTextView = layout.widthTracksTextView
        
        if textView.textContainerInset.width != layout.horizontalInset {
            textView.textContainerInset = NSSize(width: layout.horizontalInset, height: 0)
        }
        
        if let targetContainerWidth = layout.textContainerWidth,
           !textContainer.widthTracksTextView {
            if textContainer.containerSize.width != targetContainerWidth {
                textContainer.containerSize = NSSize(width: targetContainerWidth, height: CGFloat.greatestFiniteMagnitude)
            }
        }
        
        if textView.frame.width != layout.textViewWidth {
            textView.setFrameSize(NSSize(width: layout.textViewWidth, height: textView.frame.height))
        }
        
        // Force display to ensure visual update
        textView.needsDisplay = true
    }
    
    // Calculate ideal content width based on current text and font
    func calculateIdealContentWidth() -> CGFloat {
        return calculateIdealContentSize().width
    }

    func calculateIdealContentSize() -> NSSize {
        return NSSize(
            width: cachedContentWidth + NFOLayoutPolicy.horizontalWindowPadding,
            height: cachedContentHeight + NFOLayoutPolicy.verticalWindowPadding
        )
    }
    
    // MARK: - Image Export
    
    func generateImage() -> NSImage? {
        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return nil }
        
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
            showNotificationPopup(text: NSLocalizedString("COPY_AS_SVG_CONFIRMATION", value: "Copied as SVG", comment: "Confirmation shown after copying SVG"))
        } else {
            guard let image = generateImage() else { return }
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.writeObjects([image])
            showNotificationPopup(text: NSLocalizedString("COPY_AS_PNG_CONFIRMATION", value: "Copied as PNG", comment: "Confirmation shown after copying PNG"))
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
        
        let accessoryView = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: 40))
        let formatPopup = NSPopUpButton(frame: NSRect(x: 60, y: 10, width: 100, height: 24))
        formatPopup.addItems(withTitles: ["PNG", "SVG"])
        
        let formatLabel = NSLocalizedString("EXPORT_FORMAT_LABEL", value: "Format:", comment: "Label for the export format selector")
        let label = NSTextField(labelWithString: formatLabel)
        label.frame = NSRect(x: 0, y: 12, width: 55, height: 20)
        label.alignment = .right
        
        accessoryView.addSubview(label)
        accessoryView.addSubview(formatPopup)
        
        savePanel.accessoryView = accessoryView
        savePanel.canCreateDirectories = true
        savePanel.isExtensionHidden = false
        
        let copyFormat = UserDefaults.standard.string(forKey: Constants.Defaults.copyFormat) ?? "png"
        if copyFormat == "svg" {
            formatPopup.selectItem(withTitle: "SVG")
            savePanel.allowedContentTypes = [.svg]
        } else {
            formatPopup.selectItem(withTitle: "PNG")
            savePanel.allowedContentTypes = [.png]
        }
        
        savePanel.nameFieldStringValue = (self.view.window?.title ?? "Export")
        
        formatPopup.target = self
        formatPopup.action = #selector(exportFormatChanged(_:))
        guard let window = self.view.window else { return }
        activeSavePanel = savePanel
        savePanel.beginSheetModal(for: window) { [weak self] response in
            guard let self else { return }
            defer { self.activeSavePanel = nil }

            if response == .OK, let url = savePanel.url {
                let selectedFormat = formatPopup.selectedItem?.title ?? "PNG"
                do {
                    try self.writeExport(to: url, asSVG: selectedFormat == "SVG")
                } catch {
                    self.presentExportError(error)
                }
            }
        }
    }
    
    @objc func exportFormatChanged(_ sender: NSPopUpButton) {
        guard let savePanel = activeSavePanel else { return }
        let format = sender.selectedItem?.title.lowercased() ?? "png"
        savePanel.allowedContentTypes = format == "svg" ? [.svg] : [.png]
        
        let currentName = savePanel.nameFieldStringValue
        let newName = (currentName as NSString).deletingPathExtension + "." + format
        savePanel.nameFieldStringValue = newName
    }

    private func writeExport(to url: URL, asSVG: Bool) throws {
        if asSVG {
            guard let svgContent = generateSVG() else {
                throw ExportError.couldNotCreateContent
            }
            try svgContent.write(to: url, atomically: true, encoding: .utf8)
            return
        }

        guard let image = generateImage(),
              let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            throw ExportError.couldNotCreateContent
        }
        try pngData.write(to: url)
    }

    private func presentExportError(_ error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = NSLocalizedString("EXPORT_FAILED_TITLE", value: "Export Failed", comment: "Title shown when an image export cannot be saved")
        let messageFormat = NSLocalizedString("EXPORT_FAILED_MESSAGE", value: "The file could not be saved. %@", comment: "Export failure message followed by the system error")
        alert.informativeText = String(format: messageFormat, error.localizedDescription)

        if let window = view.window {
            alert.beginSheetModal(for: window)
        } else {
            alert.runModal()
        }
    }
    
    private func generateSVG() -> String? {
        guard let textStorage = textView.textStorage else { return nil }
        
        let fullString = textStorage.string as NSString
        let length = fullString.length
        
        if length == 0 { return nil }
        
        let font = textStorage.attribute(.font, at: 0, effectiveRange: nil) as? NSFont ?? NSFont.userFixedPitchFont(ofSize: 12) ?? NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        let ctFont = font as CTFont
        let ascent = CTFontGetAscent(ctFont)
        let descent = CTFontGetDescent(ctFont)
        let leading = CTFontGetLeading(ctFont)
        let lineHeight = ascent + descent + leading
        
        let padding = self.exportPadding
        
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
        
        var svg = """
        <svg xmlns="http://www.w3.org/2000/svg" width="\(width)" height="\(height)" viewBox="0 0 \(width) \(height)">
        <rect width="100%" height="100%" fill="\(bgHex)"/>
        """
        
        var currentLineIndex = 0
        
        fullString.enumerateSubstrings(in: NSRange(location: 0, length: length), options: .byLines) { (substring, substringRange, enclosingRange, stop) in
            guard substring != nil else {
                currentLineIndex += 1
                return
            }
            
            let attrString = textStorage.attributedSubstring(from: substringRange)
            
            let lineAttrString = NSMutableAttributedString(attributedString: attrString)
            if lineAttrString.length > 0 && lineAttrString.attribute(.font, at: 0, effectiveRange: nil) == nil {
                lineAttrString.addAttribute(.font, value: font, range: NSRange(location: 0, length: lineAttrString.length))
            }
            
            let line = CTLineCreateWithAttributedString(lineAttrString)
            let runs = CTLineGetGlyphRuns(line) as! [CTRun]
            
            let lineBaselineY = padding + ascent + (CGFloat(currentLineIndex) * lineHeight)
            
            for run in runs {
                let attributes = CTRunGetAttributes(run) as NSDictionary
                let runFont = attributes[kCTFontAttributeName as String] as! CTFont
                let runCount = CTRunGetGlyphCount(run)
                
                let runColor = (attributes[NSAttributedString.Key.foregroundColor] as? NSColor) ?? defaultColor
                let fillHex = self.hexString(from: runColor)
                
                for i in 0..<runCount {
                    let glyphRange = CFRangeMake(i, 1)
                    var glyph = CGGlyph()
                    var position = CGPoint()
                    
                    CTRunGetGlyphs(run, glyphRange, &glyph)
                    CTRunGetPositions(run, glyphRange, &position)
                    
                    if let path = CTFontCreatePathForGlyph(runFont, glyph, nil) {
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
    
}

private enum ExportError: LocalizedError {
    case couldNotCreateContent

    var errorDescription: String? {
        return NSLocalizedString("EXPORT_CONTENT_ERROR", value: "The image data could not be created.", comment: "Reason shown when PNG or SVG generation fails")
    }
}

extension CGPath {
    var svgPath: String {
        class PathInfo {
            var string = ""
        }
        
        let info = PathInfo()
        
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
