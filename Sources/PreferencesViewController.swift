import Cocoa

class PreferencesViewController: NSViewController {
    
    private let fontPopup = NSPopUpButton()
    private let appearancePopup = NSPopUpButton()
    private let windowSizePopup = NSPopUpButton()
    private let alignmentPopup = NSPopUpButton()
    private let copyFormatPopup = NSPopUpButton()
    private let fontSizeField = NSTextField()
    private let fontSizeStepper = NSStepper()
    private let fontSizeFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimum = NSNumber(value: Constants.FontSize.minimum)
        formatter.maximum = NSNumber(value: Constants.FontSize.maximum)
        formatter.allowsFloats = true
        formatter.maximumFractionDigits = 1
        return formatter
    }()
    
    private let textColorWell = NSColorWell()
    private let backgroundColorWell = NSColorWell()
    private let linkColorWell = NSColorWell()
    private let selectionColorWell = NSColorWell()
    
    private let highlightLinksCheckbox = NSButton()
    
    // Custom view to detect appearance changes
    private class PreferencesView: NSView {
        var onAppearanceChange: (() -> Void)?
        override func viewDidChangeEffectiveAppearance() {
            super.viewDidChangeEffectiveAppearance()
            onAppearanceChange?()
        }
    }
    
    override func loadView() {
        let v = PreferencesView(frame: NSRect(x: 0, y: 0, width: 400, height: 420))
        v.onAppearanceChange = { [weak self] in
            if ThemeManager.shared.currentMode == .system {
                self?.reloadPreferences()
            }
        }
        self.view = v
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        reloadPreferences()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(preferencesChanged(_:)),
            name: Constants.Notifications.preferencesChanged,
            object: nil
        )
    }
    
    @objc private func preferencesChanged(_: Notification) {
        reloadPreferences()
    }

    private func reloadPreferences() {
        let defaults = UserDefaults.standard

        if let fontName = defaults.string(forKey: Constants.Defaults.fontName) {
            fontPopup.selectItem(withTitle: fontName)
        }

        let mode = defaults.string(forKey: Constants.Defaults.appearanceMode) ?? "System"
        let modeIndex: Int
        switch mode {
        case "Light": modeIndex = 1
        case "Dark": modeIndex = 2
        default: modeIndex = 0
        }
        if appearancePopup.indexOfSelectedItem != modeIndex {
            appearancePopup.selectItem(at: modeIndex)
        }

        let displayedFontSize = Constants.FontSize.normalized(
            defaults.double(forKey: Constants.Defaults.fontSize)
        )
        if fontSizeField.doubleValue != displayedFontSize {
            fontSizeField.doubleValue = displayedFontSize
        }
        if fontSizeStepper.doubleValue != displayedFontSize {
            fontSizeStepper.doubleValue = displayedFontSize
        }

        let alignmentIndex: Int
        switch defaults.string(forKey: Constants.Defaults.textAlignment) ?? "Center" {
        case "Center": alignmentIndex = 1
        case "Right": alignmentIndex = 2
        default: alignmentIndex = 0
        }
        alignmentPopup.selectItem(at: alignmentIndex)

        let copyFormat = defaults.string(forKey: Constants.Defaults.copyFormat) ?? "png"
        copyFormatPopup.selectItem(withTitle: copyFormat.uppercased())

        textColorWell.color = ThemeManager.shared.textColor
        backgroundColorWell.color = ThemeManager.shared.backgroundColor
        linkColorWell.color = ThemeManager.shared.linkColor
        selectionColorWell.color = ThemeManager.shared.selectionColor
        
        highlightLinksCheckbox.state = defaults.bool(forKey: Constants.Defaults.highlightLinks) ? .on : .off
        windowSizePopup.selectItem(at: defaults.bool(forKey: Constants.Defaults.autoFitWindowSize) ? 1 : 0)
    }
    
    private func setupUI() {
        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 12
        stackView.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: view.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // Helper to localize
        func loc(_ key: String, _ defaultVal: String) -> String {
            return NSLocalizedString(key, value: defaultVal, comment: "")
        }
        
        // Font
        stackView.addArrangedSubview(createRow(label: loc("PREF_LABEL_FONT", "Font:"), control: fontPopup))
        
        // Appearance values are stored by index as System, Light, and Dark.
        appearancePopup.addItem(withTitle: loc("APPEARANCE_SYSTEM", "System"))
        appearancePopup.addItem(withTitle: loc("APPEARANCE_LIGHT", "Light"))
        appearancePopup.addItem(withTitle: loc("APPEARANCE_DARK", "Dark"))
        
        appearancePopup.target = self
        appearancePopup.action = #selector(controlChanged(_:))
        stackView.addArrangedSubview(createRow(label: loc("PREF_LABEL_APPEARANCE", "Appearance:"), control: appearancePopup))

        // Window size
        windowSizePopup.addItem(withTitle: loc("WINDOW_SIZE_STATIC", "Static"))
        windowSizePopup.addItem(withTitle: loc("WINDOW_SIZE_AUTO", "Auto-fit to content"))
        windowSizePopup.target = self
        windowSizePopup.action = #selector(controlChanged(_:))
        stackView.addArrangedSubview(createRow(label: loc("PREF_LABEL_WINDOW_SIZE", "Window size:"), control: windowSizePopup))
        
        // Alignment
        alignmentPopup.removeAllItems()
        alignmentPopup.addItem(withTitle: loc("ALIGN_LEFT", "Left"))
        alignmentPopup.addItem(withTitle: loc("ALIGN_CENTER", "Center"))
        alignmentPopup.addItem(withTitle: loc("ALIGN_RIGHT", "Right"))
        
        alignmentPopup.target = self
        alignmentPopup.action = #selector(controlChanged(_:))
        stackView.addArrangedSubview(createRow(label: loc("PREF_LABEL_ALIGNMENT", "Alignment:"), control: alignmentPopup))
        
        // Copy Format
        copyFormatPopup.removeAllItems()
        copyFormatPopup.addItem(withTitle: "PNG")
        copyFormatPopup.addItem(withTitle: "SVG")
        
        copyFormatPopup.target = self
        copyFormatPopup.action = #selector(controlChanged(_:))
        stackView.addArrangedSubview(createRow(label: loc("PREF_LABEL_COPY_FORMAT", "Copy As:"), control: copyFormatPopup))
        
        // Font Size
        let sizeStack = NSStackView()
        sizeStack.orientation = .horizontal
        fontSizeField.frame = NSRect(x: 0, y: 0, width: 50, height: 22)
        fontSizeField.delegate = self
        fontSizeField.formatter = fontSizeFormatter
        sizeStack.addArrangedSubview(fontSizeField)
        sizeStack.addArrangedSubview(fontSizeStepper)
        fontSizeStepper.minValue = Constants.FontSize.minimum
        fontSizeStepper.maxValue = Constants.FontSize.maximum
        fontSizeStepper.increment = 1
        fontSizeStepper.target = self
        fontSizeStepper.action = #selector(stepperChanged)
        stackView.addArrangedSubview(createRow(label: loc("PREF_LABEL_FONT_SIZE", "Font size:"), control: sizeStack))
        
        // Colors
        textColorWell.target = self
        textColorWell.action = #selector(colorChanged(_:))
        stackView.addArrangedSubview(createRow(label: loc("PREF_LABEL_TEXT_COLOR", "Text color:"), control: textColorWell))
        
        backgroundColorWell.target = self
        backgroundColorWell.action = #selector(colorChanged(_:))
        stackView.addArrangedSubview(createRow(label: loc("PREF_LABEL_BG_COLOR", "Background color:"), control: backgroundColorWell))
        
        linkColorWell.target = self
        linkColorWell.action = #selector(colorChanged(_:))
        stackView.addArrangedSubview(createRow(label: loc("PREF_LABEL_LINK_COLOR", "Link color:"), control: linkColorWell))
        
        selectionColorWell.target = self
        selectionColorWell.action = #selector(colorChanged(_:))
        stackView.addArrangedSubview(createRow(label: loc("PREF_LABEL_SEL_COLOR", "Selection color:"), control: selectionColorWell))
        
        // Highlight
        highlightLinksCheckbox.setButtonType(.switch)
        highlightLinksCheckbox.title = loc("PREF_CHECK_LINKS", "Enable Hyperlinks")
        highlightLinksCheckbox.target = self
        highlightLinksCheckbox.action = #selector(controlChanged(_:))
        stackView.addArrangedSubview(createRow(label: "", control: highlightLinksCheckbox))
        
        // Populate Fonts
        populateFonts()
    }
    
    private func createRow(label: String, control: NSView) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        
        let labelField = NSTextField(labelWithString: label)
        labelField.alignment = .right
        labelField.widthAnchor.constraint(equalToConstant: 130).isActive = true
        
        row.addArrangedSubview(labelField)
        row.addArrangedSubview(control)
        
        return row
    }
    
    private func populateFonts() {
        fontPopup.removeAllItems()
        let bundled = [
            "More Perfect DOS VGA",
            "ProFontWindows",
            "BlockZone",
            "FiraCode Nerd Font Mono",
            "JetBrains Mono",
            "Px437 ATI 8x14",
            "Px437 ATI 8x16",
            "Px437 ATI 8x8-2y",
            "Px437 AmstradPC1512-2y",
            "Px437 CompaqThin 8x16",
            "Px437 IBM BIOS-2y",
            "Px437 IBM CGAthin-2y",
            "Px437 IBM Conv-2y",
            "Px437 IBM ISO8",
            "Px437 IBM MDA",
            "Px437 IBM PS2thin1",
            "Px437 IBM PS2thin2",
            "Px437 IBM PS2thin3",
            "Px437 IBM PS2thin4",
            "Px437 IBM VGA8",
            "Px437 IBM VGA9",
            "Px437 TandyNew TV-2y",
            "Px437 TandyOld TV-2y",
            "Px437 VGA SquarePx",
            "Px437 Verite 8x16",
            "Px437 Verite 8x8-2y",
            "Px437 Wyse700a-2y",
            "Px437 Wyse700b-2y",
            "PxPlus IBM CGAthin-2y"
        ]
        
        for font in bundled {
            fontPopup.addItem(withTitle: font)
        }
        
        fontPopup.menu?.addItem(NSMenuItem.separator())
        
        let manager = NSFontManager.shared
        let allFonts = manager.availableFontFamilies
        
        let monospacedFonts = allFonts.filter { familyName in
            if bundled.contains(familyName) { return false }
            if familyName.hasPrefix("Px437") || familyName.hasPrefix("PxPlus") { return false }
            
            if let font = NSFont(name: familyName, size: 12) {
                return font.isFixedPitch
            }
            return false
        }
        
        for font in monospacedFonts {
            fontPopup.addItem(withTitle: font)
        }
        
        fontPopup.target = self
        fontPopup.action = #selector(controlChanged(_:))
    }
    
    @objc private func controlChanged(_ sender: NSControl) {
        let defaults = UserDefaults.standard

        if sender === fontPopup, let fontName = fontPopup.selectedItem?.title {
            guard defaults.string(forKey: Constants.Defaults.fontName) != fontName else { return }
            defaults.set(fontName, forKey: Constants.Defaults.fontName)
            notifyChange([.contentMetrics])
        } else if sender === appearancePopup {
            let modeValue: String
            switch appearancePopup.indexOfSelectedItem {
            case 1: modeValue = "Light"
            case 2: modeValue = "Dark"
            default: modeValue = "System"
            }
            ThemeManager.shared.setAppearanceMode(modeValue)
        } else if sender === alignmentPopup {
            let alignment: String
            switch alignmentPopup.indexOfSelectedItem {
            case 1: alignment = "Center"
            case 2: alignment = "Right"
            default: alignment = "Left"
            }
            guard defaults.string(forKey: Constants.Defaults.textAlignment) != alignment else { return }
            defaults.set(alignment, forKey: Constants.Defaults.textAlignment)
            notifyChange([.contentPresentation])
        } else if sender === windowSizePopup {
            let autoFitsWindow = windowSizePopup.indexOfSelectedItem == 1
            guard defaults.bool(forKey: Constants.Defaults.autoFitWindowSize) != autoFitsWindow else { return }
            defaults.set(autoFitsWindow, forKey: Constants.Defaults.autoFitWindowSize)
            notifyChange([.windowSizing])
        } else if sender === copyFormatPopup, let copyFormat = copyFormatPopup.selectedItem?.title.lowercased() {
            guard defaults.string(forKey: Constants.Defaults.copyFormat) != copyFormat else { return }
            defaults.set(copyFormat, forKey: Constants.Defaults.copyFormat)
            notifyChange([.copyFormat])
        } else if sender === highlightLinksCheckbox {
            let highlightsLinks = highlightLinksCheckbox.state == .on
            guard defaults.bool(forKey: Constants.Defaults.highlightLinks) != highlightsLinks else { return }
            defaults.set(highlightsLinks, forKey: Constants.Defaults.highlightLinks)
            notifyChange([.contentPresentation])
        }
    }
    
    @objc private func stepperChanged() {
        fontSizeField.doubleValue = fontSizeStepper.doubleValue
        saveFontSize(fontSizeStepper.doubleValue)
    }
    
    @objc private func colorChanged(_ sender: NSColorWell) {
        if sender === textColorWell {
            saveColor(color: sender.color, key: Constants.Defaults.textColor)
        } else if sender === backgroundColorWell {
            saveColor(color: sender.color, key: Constants.Defaults.backgroundColor)
        } else if sender === linkColorWell {
            saveColor(color: sender.color, key: Constants.Defaults.linkColor)
        } else if sender === selectionColorWell {
            saveColor(color: sender.color, key: Constants.Defaults.selectionColor)
        } else {
            return
        }
        notifyChange([.appearance])
    }

    private func saveFontSize(_ proposedSize: Double) {
        let fontSize = min(
            max(proposedSize, Constants.FontSize.minimum),
            Constants.FontSize.maximum
        )
        fontSizeField.doubleValue = fontSize
        fontSizeStepper.doubleValue = fontSize

        let defaults = UserDefaults.standard
        guard defaults.double(forKey: Constants.Defaults.fontSize) != fontSize else { return }
        defaults.set(fontSize, forKey: Constants.Defaults.fontSize)
        notifyChange([.contentMetrics])
    }
    
    private func notifyChange(_ changes: Set<PreferenceChange>) {
        ThemeManager.shared.notifyPreferencesChanged(changes)
    }
    
    private func saveColor(color: NSColor, key: String) {
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: color, requiringSecureCoding: false) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

extension PreferencesViewController: NSTextFieldDelegate {
    func controlTextDidEndEditing(_ obj: Notification) {
        guard let field = obj.object as? NSTextField, field === fontSizeField else { return }
        guard let number = fontSizeFormatter.number(from: field.stringValue) else {
            reloadPreferences()
            return
        }
        saveFontSize(number.doubleValue)
    }
}
