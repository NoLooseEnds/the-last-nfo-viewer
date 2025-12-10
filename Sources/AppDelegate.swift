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
        
        // If no documents are open (e.g. app launched directly), show the open panel
        DispatchQueue.main.async {
            if NSDocumentController.shared.documents.isEmpty {
                NSDocumentController.shared.openDocument(self)
            }
        }
    }
    
    private func registerDefaults() {
        // Centralized defaults registration
        UserDefaults.standard.register(defaults: [
            Constants.Defaults.fontName: "More Perfect DOS VGA",
            Constants.Defaults.fontSize: 14.0,
            Constants.Defaults.highlightLinks: true,
            Constants.Defaults.appearanceMode: "System",
            Constants.Defaults.textAlignment: "Center"
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
        
        let resetTitle = NSLocalizedString("MENU_RESET_FONT", value: "Actual Size", comment: "Menu item to reset font size")
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
        
        // Find "Export..." or "Save As..." to place our item nearby
        // Using generic saveDocumentAs: selector
        let saveAsSelector = NSSelectorFromString("saveDocumentAs:")
        let index = fileMenu.indexOfItem(withTarget: nil, andAction: saveAsSelector)
        
        if index >= 0 {
             let exportImageTitle = NSLocalizedString("MENU_EXPORT_IMAGE", value: "Export as Image…", comment: "Menu item for Export as Image")
             // Check if already exists
             if fileMenu.item(withTitle: exportImageTitle) == nil {
                 let exportImageItem = NSMenuItem(title: exportImageTitle, action: #selector(ViewController.exportAsImage(_:)), keyEquivalent: "")
                 fileMenu.insertItem(exportImageItem, at: index + 1)
             }
        }
    }
    
    private func setupEditMenu() {
        guard let mainMenu = NSApplication.shared.mainMenu,
              let editMenu = mainMenu.item(withTitle: "Edit")?.submenu else { return }
        
        // Find "Copy" item
        let copySelector = NSSelectorFromString("copy:")
        let index = editMenu.indexOfItem(withTarget: nil, andAction: copySelector)
        
        if index >= 0 {
             let copyImageTitle = NSLocalizedString("MENU_COPY_IMAGE", value: "Copy as Image", comment: "Menu item for Copy as Image")
             // Check if already exists
             if editMenu.item(withTitle: copyImageTitle) == nil {
                 let copyImageItem = NSMenuItem(title: copyImageTitle, action: #selector(ViewController.copyAsImage(_:)), keyEquivalent: "C")
                 copyImageItem.keyEquivalentModifierMask = [.command, .shift]
                 
                 editMenu.insertItem(copyImageItem, at: index + 1)
             }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        return false
    }
}
