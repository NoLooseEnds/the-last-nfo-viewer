import Cocoa

class PreferencesViewController: NSViewController {
    
    private let fontPopup = NSPopUpButton()
    private let appearancePopup = NSPopUpButton()
    private let alignmentPopup = NSPopUpButton()
    private let fontSizeField = NSTextField()
    private let fontSizeStepper = NSStepper()
    
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
        let v = PreferencesView(frame: NSRect(x: 0, y: 0, width: 400, height: 380))
        v.onAppearanceChange = { [weak self] in
            if ThemeManager.shared.currentMode == .system {
                self?.preferencesChanged()
            }
        }
        self.view = v
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadPreferences()
        
        NotificationCenter.default.addObserver(self, selector: #selector(preferencesChanged), name: Constants.Notifications.preferencesChanged, object: nil)
    }
    
    @objc private func preferencesChanged() {
        // Reload color wells as they might have been reset by a mode change
        // Use ThemeManager to get the effective color (resolves defaults based on new mode)
        textColorWell.color = ThemeManager.shared.textColor
        backgroundColorWell.color = ThemeManager.shared.backgroundColor
        linkColorWell.color = ThemeManager.shared.linkColor
        selectionColorWell.color = ThemeManager.shared.selectionColor
        
        // Update highlighting checkbox if changed externally
        highlightLinksCheckbox.state = UserDefaults.standard.bool(forKey: Constants.Defaults.highlightLinks) ? .on : .off
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
        
        // Appearance
        appearancePopup.addItems(withTitles: ["System", "Light", "Dark"]) // These are internal values usually, but displayed. Should we localize?
        // The internal values are stored as "System", "Light", "Dark" in ThemeManager.
        // If we localize the menu items, we must map them back.
        // For simplicity, let's keep English names for now or implement mapping.
        // Best practice: Use tags or a separate array for values.
        // Let's map indices to values: 0->System, 1->Light, 2->Dark
        appearancePopup.removeAllItems()
        appearancePopup.addItem(withTitle: loc("APPEARANCE_SYSTEM", "System"))
        appearancePopup.addItem(withTitle: loc("APPEARANCE_LIGHT", "Light"))
        appearancePopup.addItem(withTitle: loc("APPEARANCE_DARK", "Dark"))
        
        appearancePopup.target = self
        appearancePopup.action = #selector(controlChanged)
        stackView.addArrangedSubview(createRow(label: loc("PREF_LABEL_APPEARANCE", "Appearance:"), control: appearancePopup))
        
        // Alignment
        alignmentPopup.removeAllItems()
        alignmentPopup.addItem(withTitle: loc("ALIGN_LEFT", "Left"))
        alignmentPopup.addItem(withTitle: loc("ALIGN_CENTER", "Center"))
        alignmentPopup.addItem(withTitle: loc("ALIGN_RIGHT", "Right"))
        
        alignmentPopup.target = self
        alignmentPopup.action = #selector(controlChanged)
        stackView.addArrangedSubview(createRow(label: loc("PREF_LABEL_ALIGNMENT", "Alignment:"), control: alignmentPopup))
        
        // Font Size
        let sizeStack = NSStackView()
        sizeStack.orientation = .horizontal
        fontSizeField.frame = NSRect(x: 0, y: 0, width: 50, height: 22)
        fontSizeField.delegate = self
        sizeStack.addArrangedSubview(fontSizeField)
        sizeStack.addArrangedSubview(fontSizeStepper)
        fontSizeStepper.target = self
        fontSizeStepper.action = #selector(stepperChanged)
        stackView.addArrangedSubview(createRow(label: loc("PREF_LABEL_FONT_SIZE", "Font size:"), control: sizeStack))
        
        // Colors
        textColorWell.target = self
        textColorWell.action = #selector(colorChanged)
        stackView.addArrangedSubview(createRow(label: loc("PREF_LABEL_TEXT_COLOR", "Text color:"), control: textColorWell))
        
        backgroundColorWell.target = self
        backgroundColorWell.action = #selector(colorChanged)
        stackView.addArrangedSubview(createRow(label: loc("PREF_LABEL_BG_COLOR", "Background color:"), control: backgroundColorWell))
        
        linkColorWell.target = self
        linkColorWell.action = #selector(colorChanged)
        stackView.addArrangedSubview(createRow(label: loc("PREF_LABEL_LINK_COLOR", "Link color:"), control: linkColorWell))
        
        selectionColorWell.target = self
        selectionColorWell.action = #selector(colorChanged)
        stackView.addArrangedSubview(createRow(label: loc("PREF_LABEL_SEL_COLOR", "Selection color:"), control: selectionColorWell))
        
        // Highlight
        highlightLinksCheckbox.setButtonType(.switch)
        highlightLinksCheckbox.title = loc("PREF_CHECK_LINKS", "Enable Hyperlinks")
        highlightLinksCheckbox.target = self
        highlightLinksCheckbox.action = #selector(controlChanged)
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
        
        // Removed System Fonts header as requested, just the separator remains
        
        let manager = NSFontManager.shared
        let allFonts = manager.availableFontFamilies
        
        let monospacedFonts = allFonts.filter { familyName in
            if bundled.contains(familyName) { return false }
            // Filter out our bundled fonts if they show up in system fonts (e.g. installed or recognized differently)
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
        fontPopup.action = #selector(controlChanged)
    }
    
    private func loadPreferences() {
        let defaults = UserDefaults.standard
        
        if let fontName = defaults.string(forKey: Constants.Defaults.fontName) {
            fontPopup.selectItem(withTitle: fontName)
        }
        
        // Map internal values to localized UI
        let mode = defaults.string(forKey: Constants.Defaults.appearanceMode) ?? "System"
        let modeIndex: Int
        switch mode {
        case "Light": modeIndex = 1
        case "Dark": modeIndex = 2
        default: modeIndex = 0
        }
        appearancePopup.selectItem(at: modeIndex)
        
        let align = defaults.string(forKey: Constants.Defaults.textAlignment) ?? "Center"
        let alignIndex: Int
        switch align {
        case "Center": alignIndex = 1
        case "Right": alignIndex = 2
        default: alignIndex = 0 // Left
        }
        alignmentPopup.selectItem(at: alignIndex)
        
        let fontSize = defaults.double(forKey: Constants.Defaults.fontSize)
        fontSizeField.doubleValue = fontSize > 0 ? fontSize : 16.0
        fontSizeStepper.doubleValue = fontSizeField.doubleValue
        
        highlightLinksCheckbox.state = defaults.bool(forKey: Constants.Defaults.highlightLinks) ? .on : .off
        
        // Use ThemeManager to get effective colors (handling System mode correctly)
        textColorWell.color = ThemeManager.shared.textColor
        backgroundColorWell.color = ThemeManager.shared.backgroundColor
        linkColorWell.color = ThemeManager.shared.linkColor
        selectionColorWell.color = ThemeManager.shared.selectionColor
    }
    
    @objc private func controlChanged() {
        let defaults = UserDefaults.standard
        
        defaults.set(fontPopup.selectedItem?.title, forKey: Constants.Defaults.fontName)
        
        // Map UI index back to internal value
        let modeIndex = appearancePopup.indexOfSelectedItem
        let modeValue: String
        switch modeIndex {
        case 1: modeValue = "Light"
        case 2: modeValue = "Dark"
        default: modeValue = "System"
        }
        ThemeManager.shared.setAppearanceMode(modeValue)
        
        let alignIndex = alignmentPopup.indexOfSelectedItem
        let alignValue: String
        switch alignIndex {
        case 1: alignValue = "Center"
        case 2: alignValue = "Right"
        default: alignValue = "Left"
        }
        defaults.set(alignValue, forKey: Constants.Defaults.textAlignment)
        
        defaults.set(highlightLinksCheckbox.state == .on, forKey: Constants.Defaults.highlightLinks)
        
        notifyChange()
    }
    
    @objc private func stepperChanged() {
        fontSizeField.doubleValue = fontSizeStepper.doubleValue
        UserDefaults.standard.set(fontSizeField.doubleValue, forKey: Constants.Defaults.fontSize)
        notifyChange()
    }
    
    @objc private func colorChanged() {
        saveColor(color: textColorWell.color, key: Constants.Defaults.textColor)
        saveColor(color: backgroundColorWell.color, key: Constants.Defaults.backgroundColor)
        saveColor(color: linkColorWell.color, key: Constants.Defaults.linkColor)
        saveColor(color: selectionColorWell.color, key: Constants.Defaults.selectionColor)
        notifyChange()
    }
    
    private func notifyChange() {
        ThemeManager.shared.notifyPreferencesChanged()
    }
    
    private func loadColor(key: String) -> NSColor? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data)
    }
    
    private func saveColor(color: NSColor, key: String) {
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: color, requiringSecureCoding: false) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

extension PreferencesViewController: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        if let field = obj.object as? NSTextField, field == fontSizeField {
            fontSizeStepper.doubleValue = field.doubleValue
            UserDefaults.standard.set(field.doubleValue, forKey: Constants.Defaults.fontSize)
            notifyChange()
        }
    }
}
