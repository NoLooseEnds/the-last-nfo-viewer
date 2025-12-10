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
        
        let exportImageTitle = NSLocalizedString("MENU_EXPORT_IMAGE", value: "Export as Image…", comment: "Menu item for Export as Image")
        if fileMenu.item(withTitle: exportImageTitle) == nil {
             let exportImageItem = NSMenuItem(title: exportImageTitle, action: #selector(ViewController.exportAsImage(_:)), keyEquivalent: "E")
             exportImageItem.keyEquivalentModifierMask = [.command] // Cmd+E for Export Image? Or just standard.
             // Standard Export is usually Cmd+Shift+E or similar. Let's leave no shortcut or use Shift+Cmd+E
             exportImageItem.keyEquivalentModifierMask = [.command, .shift]
             exportImageItem.keyEquivalent = "e"
             
             fileMenu.insertItem(exportImageItem, at: targetIndex)
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
