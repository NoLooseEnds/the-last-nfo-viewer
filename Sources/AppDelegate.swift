import Cocoa

@NSApplicationMain
@objc(AppDelegate)
class AppDelegate: NSObject, NSApplicationDelegate {

    var preferencesWindowController: NSWindowController?
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        migrateLegacyDefaults()
        registerDefaults()
        ThemeManager.shared.synchronizeSharedConfig()
        
        setupViewMenu()
        setupPreferencesMenu()
        setupExportMenu()
        setupEditMenu()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(preferencesDidChange(_:)),
            name: Constants.Notifications.preferencesChanged,
            object: nil
        )
        
        updateEditMenu()
        
        // If no documents are open (e.g. app launched directly), show the open panel
        DispatchQueue.main.async {
            if NSDocumentController.shared.documents.isEmpty {
                NSDocumentController.shared.openDocument(self)
            }
        }
    }
    
    @objc func updateEditMenu() {
        guard let mainMenu = NSApplication.shared.mainMenu else { return }

        let copySelector = NSSelectorFromString("copy:")
        guard let editMenu = submenu(containing: copySelector, in: mainMenu) else { return }
        
        let copyFormat = UserDefaults.standard.string(forKey: Constants.Defaults.copyFormat) ?? "png"
        let isSVG = copyFormat == "svg"

        let pngTitle = NSLocalizedString("MENU_COPY_AS_PNG", value: "Copy as PNG", comment: "Menu item that copies the document as PNG")
        let svgTitle = NSLocalizedString("MENU_COPY_AS_SVG", value: "Copy as SVG", comment: "Menu item that copies the document as SVG")
        let primaryTitle = isSVG ? svgTitle : pngTitle
        let alternateTitle = isSVG ? pngTitle : svgTitle

        let copyIndex = editMenu.indexOfItem(withTarget: nil, andAction: copySelector)
        guard copyIndex >= 0 else { return }

        let primarySelector = #selector(ViewController.copyAsImage(_:))
        let alternateSelector = #selector(ViewController.copyAsAlternateImage(_:))

        for item in editMenu.items.reversed() {
            if item.action == primarySelector || item.action == alternateSelector {
                editMenu.removeItem(item)
            }
        }
        
        let primaryItem = NSMenuItem(title: primaryTitle, action: primarySelector, keyEquivalent: "c")
        primaryItem.keyEquivalentModifierMask = [.command, .shift]

        let alternateItem = NSMenuItem(title: alternateTitle, action: alternateSelector, keyEquivalent: "c")
        alternateItem.keyEquivalentModifierMask = [.command, .shift, .option]
        alternateItem.isAlternate = true
        
        editMenu.insertItem(alternateItem, at: copyIndex + 1)
        editMenu.insertItem(primaryItem, at: copyIndex + 1)
    }

    @objc private func preferencesDidChange(_ notification: Notification) {
        let changes = PreferenceChange.changes(from: notification)
        if changes.contains(.copyFormat) {
            updateEditMenu()
        }
    }

    private func migrateLegacyDefaults() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: Constants.Defaults.autoFitWindowSize) == nil,
           let legacyValue = defaults.object(forKey: Constants.Defaults.legacyAutoFitWindowWidth) {
            defaults.set(legacyValue, forKey: Constants.Defaults.autoFitWindowSize)
        }

        defaults.removeObject(forKey: Constants.Defaults.legacyAutoFitWindowWidth)
    }
    
    private func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            Constants.Defaults.fontName: "More Perfect DOS VGA",
            Constants.Defaults.fontSize: Constants.FontSize.defaultValue,
            Constants.Defaults.highlightLinks: true,
            Constants.Defaults.appearanceMode: "System",
            Constants.Defaults.textAlignment: "Center",
            Constants.Defaults.copyFormat: "png",
            Constants.Defaults.autoFitWindowSize: true
        ])
    }
    
    private func setupPreferencesMenu() {
        let mainMenu = NSApplication.shared.mainMenu
        if let appMenu = mainMenu?.items.first?.submenu {
            // Clean up existing items to avoid duplication
            for item in appMenu.items {
                if item.title.contains("Preferences") || item.title.contains("Settings") {
                    if item.action != #selector(showPreferences) {
                        appMenu.removeItem(item)
                    }
                }
            }
            
            let settingsTitle = NSLocalizedString("MENU_SETTINGS", value: "Settings…", comment: "Menu item for Settings")
            let prefsTitle = NSLocalizedString("MENU_PREFERENCES", value: "Preferences…", comment: "Menu item for Preferences")
            
            if appMenu.item(withTitle: settingsTitle) == nil && appMenu.item(withTitle: prefsTitle) == nil {
                let title = ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 13 ? settingsTitle : prefsTitle
                let prefsItem = NSMenuItem(title: title, action: #selector(showPreferences), keyEquivalent: ",")
                appMenu.insertItem(prefsItem, at: 2)
            }
        }
    }
    
    @objc func showPreferences() {
        if preferencesWindowController == nil {
            let preferencesVC = PreferencesViewController()
            let window = NSWindow(contentViewController: preferencesVC)
            window.title = NSLocalizedString("WINDOW_PREFERENCES", value: "Preferences", comment: "Preferences window title")
            window.styleMask = NSWindow.StyleMask([.titled, .closable])
            window.setContentSize(NSSize(width: 400, height: 420))
            
            preferencesWindowController = NSWindowController(window: window)
        }
        
        preferencesWindowController?.showWindow(self)
        preferencesWindowController?.window?.makeKeyAndOrderFront(self)
    }
    
    private func setupViewMenu() {
        let mainMenu = NSApplication.shared.mainMenu
        let viewTitle = NSLocalizedString("MENU_VIEW", value: "View", comment: "View menu title")

        if mainMenu?.item(withTitle: viewTitle) != nil { return }

        let viewMenuItem = NSMenuItem(title: viewTitle, action: nil, keyEquivalent: "")
        let viewMenu = NSMenu(title: viewTitle)
        viewMenuItem.submenu = viewMenu
        
        let toggleTitle = NSLocalizedString("MENU_TOGGLE_DARK_MODE", value: "Toggle Dark Mode", comment: "Menu item to toggle dark mode")
        let toggleDarkModeItem = NSMenuItem(title: toggleTitle, action: #selector(toggleDarkMode), keyEquivalent: "d")
        toggleDarkModeItem.target = self
        toggleDarkModeItem.keyEquivalentModifierMask = [.command, .shift]
        viewMenu.addItem(toggleDarkModeItem)

        let autoFitTitle = NSLocalizedString("MENU_AUTO_FIT_WINDOW", value: "Auto-fit Window to Content", comment: "Menu item that toggles automatic document window sizing")
        let autoFitItem = NSMenuItem(title: autoFitTitle, action: #selector(toggleAutoFitWindow), keyEquivalent: "")
        autoFitItem.target = self
        viewMenu.addItem(autoFitItem)
        
        viewMenu.addItem(NSMenuItem.separator())
        
        let increaseTitle = NSLocalizedString("MENU_INCREASE_FONT", value: "Increase Font Size", comment: "Menu item to increase font size")
        let increaseItem = NSMenuItem(title: increaseTitle, action: #selector(increaseFontSize), keyEquivalent: "+")
        increaseItem.target = self
        increaseItem.keyEquivalentModifierMask = [.command]
        viewMenu.addItem(increaseItem)
        
        let decreaseTitle = NSLocalizedString("MENU_DECREASE_FONT", value: "Decrease Font Size", comment: "Menu item to decrease font size")
        let decreaseItem = NSMenuItem(title: decreaseTitle, action: #selector(decreaseFontSize), keyEquivalent: "-")
        decreaseItem.target = self
        decreaseItem.keyEquivalentModifierMask = [.command]
        viewMenu.addItem(decreaseItem)
        
        let resetTitle = NSLocalizedString("MENU_RESET_FONT", value: "Default Font Size", comment: "Menu item to reset font size")
        let resetItem = NSMenuItem(title: resetTitle, action: #selector(resetFontSize), keyEquivalent: "0")
        resetItem.target = self
        resetItem.keyEquivalentModifierMask = [.command]
        viewMenu.addItem(resetItem)
        
        if let mainMenu,
           let windowMenu = NSApplication.shared.windowsMenu,
           let windowItem = mainMenu.items.first(where: { $0.submenu === windowMenu }) {
            let windowIndex = mainMenu.index(of: windowItem)
            mainMenu.insertItem(viewMenuItem, at: windowIndex)
        } else {
            mainMenu?.addItem(viewMenuItem)
        }
    }

    @objc private func toggleDarkMode() {
        ThemeManager.shared.toggleDarkMode()
    }

    @objc private func toggleAutoFitWindow() {
        let defaults = UserDefaults.standard
        let automaticallyFitsWindow = defaults.bool(forKey: Constants.Defaults.autoFitWindowSize)
        defaults.set(!automaticallyFitsWindow, forKey: Constants.Defaults.autoFitWindowSize)
        ThemeManager.shared.notifyPreferencesChanged([.windowSizing])
    }

    @objc private func increaseFontSize() {
        ThemeManager.shared.increaseFontSize()
    }

    @objc private func decreaseFontSize() {
        ThemeManager.shared.decreaseFontSize()
    }

    @objc private func resetFontSize() {
        ThemeManager.shared.resetFontSize()
    }
    
    private func setupExportMenu() {
        guard let mainMenu = NSApplication.shared.mainMenu else { return }

        let printSelector = NSSelectorFromString("print:")
        guard let fileMenu = submenu(containing: printSelector, in: mainMenu) else { return }
        
        let saveAsSelector = NSSelectorFromString("saveDocumentAs:")
        let saveAsIndex = fileMenu.indexOfItem(withTarget: nil, andAction: saveAsSelector)
        if saveAsIndex >= 0 {
            fileMenu.removeItem(at: saveAsIndex)
        }
        
        let printIndex = fileMenu.indexOfItem(withTarget: nil, andAction: printSelector)
        
        let targetIndex = printIndex >= 0 ? printIndex : fileMenu.numberOfItems
        
        let exportTitle = NSLocalizedString("MENU_EXPORT", value: "Export…", comment: "Menu item for Export")
        if fileMenu.item(withTitle: exportTitle) == nil {
            let exportItem = NSMenuItem(title: exportTitle, action: #selector(ViewController.exportFile(_:)), keyEquivalent: "E")
            exportItem.keyEquivalentModifierMask = [.command, .shift]
            exportItem.keyEquivalent = "e"

            fileMenu.insertItem(exportItem, at: targetIndex)
        }
    }
    
    private func setupEditMenu() {
        updateEditMenu()
    }

    private func submenu(containing action: Selector, in mainMenu: NSMenu) -> NSMenu? {
        return mainMenu.items
            .compactMap(\.submenu)
            .first { $0.indexOfItem(withTarget: nil, andAction: action) >= 0 }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        return false
    }
}

extension AppDelegate: NSMenuItemValidation {
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(toggleAutoFitWindow) {
            menuItem.state = UserDefaults.standard.bool(forKey: Constants.Defaults.autoFitWindowSize) ? .on : .off
        }

        return true
    }
}
