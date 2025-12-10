import Cocoa

@NSApplicationMain
@objc(AppDelegate)
class AppDelegate: NSObject, NSApplicationDelegate {

    var preferencesWindowController: NSWindowController?
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Register defaults early
        registerDefaults()
        
        // Setup View Menu
        setupViewMenu()
        setupPreferencesMenu()
        setupExportMenu()
        setupEditMenu()
        
        // Observe preference changes to update menu
        NotificationCenter.default.addObserver(self, selector: #selector(updateEditMenu), name: Constants.Notifications.preferencesChanged, object: nil)
        
        // Initial update
        updateEditMenu()
        
        // If no documents are open (e.g. app launched directly), show the open panel
        DispatchQueue.main.async {
            if NSDocumentController.shared.documents.isEmpty {
                NSDocumentController.shared.openDocument(self)
            }
        }
    }
    
    @objc func updateEditMenu() {
        guard let mainMenu = NSApplication.shared.mainMenu,
              let editMenu = mainMenu.item(withTitle: "Edit")?.submenu else { return }
        
        // Determine preferred format
        let copyFormat = UserDefaults.standard.string(forKey: Constants.Defaults.copyFormat) ?? "png"
        let isSVG = copyFormat == "svg"
        
        // Use spaces to try and align width. SVG is narrower than PNG, so padding SVG.
        // "Copy as SVG " vs "Copy as PNG"
        let primaryTitle = isSVG ? "Copy as SVG " : "Copy as PNG"
        let alternateTitle = isSVG ? "Copy as PNG" : "Copy as SVG "
        
        // Find existing items or insert new ones
        // We use a specific tag to identify our items if we want, but searching by selector is safer if we change titles.
        // Let's rely on finding them by action or just rebuilding them.
        // Since we insert them at index + 1 of standard Copy, let's find that again.
        
        let copySelector = NSSelectorFromString("copy:")
        let copyIndex = editMenu.indexOfItem(withTarget: nil, andAction: copySelector)
        
        guard copyIndex >= 0 else { return }
        
        // Remove existing custom items (identified by their selectors)
        // We look for copyAsImage: and copyAsAlternateImage:
        let primarySelector = #selector(ViewController.copyAsImage(_:))
        let alternateSelector = #selector(ViewController.copyAsAlternateImage(_:))
        
        // Safely remove items if they exist
        // Note: Removing by action might remove others if we are not careful, but these are specific to us.
        // We iterate backwards to avoid index shifting issues
        for item in editMenu.items.reversed() {
            if item.action == primarySelector || item.action == alternateSelector {
                editMenu.removeItem(item)
            }
        }
        
        // Re-insert items
        // 1. Primary Item (Cmd+Shift+C)
        let primaryItem = NSMenuItem(title: primaryTitle, action: primarySelector, keyEquivalent: "c")
        primaryItem.keyEquivalentModifierMask = [.command, .shift]
        
        // 2. Alternate Item (Cmd+Shift+Option+C) - Swaps format
        // We use the same key equivalent "c" but with option modifier added.
        // In Cocoa, setting isAlternate = true and same key equivalent usually works for simple modifiers (like Option).
        // But for complex combos (Cmd+Shift+C vs Cmd+Shift+Option+C), explicit items are often clearer.
        // To make it an "Alternate" in the menu sense (hides main, shows this when Option pressed):
        // It must share the same key equivalent (ignoring modifiers? No, modifiers must match the alternate state).
        // Actually, for "Alternate" menu items, they usually have the same key equivalent but different modifiers.
        // Let's set it up explicitly.
        
        let alternateItem = NSMenuItem(title: alternateTitle, action: alternateSelector, keyEquivalent: "c")
        alternateItem.keyEquivalentModifierMask = [.command, .shift, .option]
        alternateItem.isAlternate = true
        
        // Insert in order: Primary then Alternate (standard order for alternates)
        editMenu.insertItem(alternateItem, at: copyIndex + 1)
        editMenu.insertItem(primaryItem, at: copyIndex + 1)
    }
    
    private func registerDefaults() {
        // Centralized defaults registration
        UserDefaults.standard.register(defaults: [
            Constants.Defaults.fontName: "More Perfect DOS VGA",
            Constants.Defaults.fontSize: 14.0,
            Constants.Defaults.highlightLinks: true,
            Constants.Defaults.appearanceMode: "System",
            Constants.Defaults.textAlignment: "Center",
            Constants.Defaults.copyFormat: "png"
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
            window.setContentSize(NSSize(width: 400, height: 380)) // Slightly taller for comfort
            
            preferencesWindowController = NSWindowController(window: window)
        }
        
        preferencesWindowController?.showWindow(self)
        preferencesWindowController?.window?.makeKeyAndOrderFront(self)
    }
    
    private func setupViewMenu() {
        let mainMenu = NSApplication.shared.mainMenu
        
        if mainMenu?.item(withTitle: "View") != nil { return }
        
        let viewTitle = NSLocalizedString("MENU_VIEW", value: "View", comment: "View menu title")
        let viewMenuItem = NSMenuItem(title: viewTitle, action: nil, keyEquivalent: "")
        let viewMenu = NSMenu(title: viewTitle)
        viewMenuItem.submenu = viewMenu
        
        let toggleTitle = NSLocalizedString("MENU_TOGGLE_DARK_MODE", value: "Toggle Dark Mode", comment: "Menu item to toggle dark mode")
        let toggleDarkModeItem = NSMenuItem(title: toggleTitle, action: #selector(ViewController.toggleDarkMode), keyEquivalent: "d")
        toggleDarkModeItem.keyEquivalentModifierMask = [.command, .shift]
        viewMenu.addItem(toggleDarkModeItem)
        
        viewMenu.addItem(NSMenuItem.separator())
        
        let increaseTitle = NSLocalizedString("MENU_INCREASE_FONT", value: "Increase Font Size", comment: "Menu item to increase font size")
        let increaseItem = NSMenuItem(title: increaseTitle, action: #selector(ViewController.increaseFontSize), keyEquivalent: "+")
        increaseItem.keyEquivalentModifierMask = [.command]
        viewMenu.addItem(increaseItem)
        
        let decreaseTitle = NSLocalizedString("MENU_DECREASE_FONT", value: "Decrease Font Size", comment: "Menu item to decrease font size")
        let decreaseItem = NSMenuItem(title: decreaseTitle, action: #selector(ViewController.decreaseFontSize), keyEquivalent: "-")
        decreaseItem.keyEquivalentModifierMask = [.command]
        viewMenu.addItem(decreaseItem)
        
        let resetTitle = NSLocalizedString("MENU_RESET_FONT", value: "Default Font Size", comment: "Menu item to reset font size")
        let resetItem = NSMenuItem(title: resetTitle, action: #selector(ViewController.resetFontSize), keyEquivalent: "0")
        resetItem.keyEquivalentModifierMask = [.command]
        viewMenu.addItem(resetItem)
        
        if let windowMenu = mainMenu?.item(withTitle: "Window"),
           let windowIndex = mainMenu?.index(of: windowMenu) {
            mainMenu?.insertItem(viewMenuItem, at: windowIndex)
        } else {
            mainMenu?.addItem(viewMenuItem)
        }
    }
    
    private func setupExportMenu() {
        guard let mainMenu = NSApplication.shared.mainMenu,
              let fileMenu = mainMenu.item(withTitle: "File")?.submenu else { return }
        
        // Remove standard "Export..." item if it exists (usually added by IB)
        // Its selector is typically saveDocumentAs: but we can search by title to be sure, or tag.
        // The "Export..." item we see is likely standard Cocoa behavior or from the XIB.
        // Let's remove the item that calls saveDocumentAs: if it's the standard one
        // and replace it with our own, or just remove it if we don't want it.
        // User asked "what is the Export function", implying they don't want the PDF/standard one.
        // We will remove it.
        
        let saveAsSelector = NSSelectorFromString("saveDocumentAs:")
        if let index = fileMenu.indexOfItem(withTarget: nil, andAction: saveAsSelector) as Int?, index >= 0 {
             fileMenu.removeItem(at: index)
        }
        
        // Find "Print..." to place our item nearby (usually export is near print/save)
        let printSelector = NSSelectorFromString("print:")
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
        // Initial setup handled by updateEditMenu
        updateEditMenu()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        return false
    }
}
