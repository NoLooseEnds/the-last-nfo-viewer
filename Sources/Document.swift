import Cocoa

@objc(Document)
class Document: NSDocument, NSWindowDelegate {
    
    var textContent: String = ""
    
    override class var autosavesInPlace: Bool {
        return false
    }

    override init() {
        super.init()
    }

    override func makeWindowControllers() {
        let viewController = ViewController()
        viewController.textContent = self.textContent
        
        // Create a window for the view controller
        // We use a default size, but the ViewController will likely resize it based on content
        let window = NSWindow(contentRect: NSMakeRect(0, 0, 800, 600),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered, defer: false)
        
        window.delegate = self
        
        let windowController = NSWindowController(window: window)
        windowController.contentViewController = viewController
        
        self.addWindowController(windowController)
        
        // Ensure the window has the document's title
        windowController.window?.title = self.displayName
        
        // Center the window if no saved state exists, otherwise it will be restored by Cocoa
        if !window.setFrameUsingName("DocumentWindow") {
            window.center()
        }
        window.setFrameAutosaveName("DocumentWindow")
        
        windowController.showWindow(self)
        window.makeKeyAndOrderFront(self)
    }

    override func read(from data: Data, ofType typeName: String) throws {
        // CP437 (DOS) encoding
        let cfEncoding = CFStringConvertWindowsCodepageToEncoding(437)
        let nsEncoding = CFStringConvertEncodingToNSStringEncoding(cfEncoding)
        let encoding = String.Encoding(rawValue: nsEncoding)
        
        if let content = String(data: data, encoding: encoding) {
            self.textContent = content
        } else {
            // Fallback to ASCII or UTF8 if CP437 fails (unlikely for Data)
             if let content = String(data: data, encoding: .ascii) {
                 self.textContent = content
             } else {
                 throw NSError(domain: NSCocoaErrorDomain, code: NSFileReadUnknownError, userInfo: nil)
             }
        }
        
        // Remove trailing CR/LF as in the original code
        if self.textContent.hasSuffix("\n") {
            self.textContent = String(self.textContent.dropLast())
            if self.textContent.hasSuffix("\r") {
                self.textContent = String(self.textContent.dropLast())
            }
        }
    }
    
    override func prepareSavePanel(_ savePanel: NSSavePanel) -> Bool {
        savePanel.isExtensionHidden = false
        return true
    }
    
    override func data(ofType typeName: String) throws -> Data {
        // We'll just save as UTF-8 for now, or use the original encoding if we tracked it.
        // But for "Save As", UTF-8 is a safe modern default unless we strictly want to preserve CP437.
        // Let's use UTF-8 for compatibility.
        return textContent.data(using: .utf8) ?? Data()
    }
    
    // MARK: - NSWindowDelegate
    
    func windowWillUseStandardFrame(_ window: NSWindow, defaultFrame newFrame: NSRect) -> NSRect {
        guard let windowController = self.windowControllers.first,
              let viewController = windowController.contentViewController as? ViewController else {
            return newFrame
        }
        
        // Calculate ideal width
        let idealWidth = viewController.calculateIdealContentWidth()
        
        // We want to fit to width, but maximize height (or keep default maximized height)
        // User requested: "Fit to content is only width"
        // And "toggle between full window and fit to content"
        // "Full window" usually implies maximizing both width and height.
        // So standard frame (zoomed) should probably satisfy "Fit Width".
        // But if the user wants "Full Window", they can maximize.
        // Wait, standard Zoom toggles between User Size and Standard Frame.
        // If I make Standard Frame = Fit Width + Max Height, then:
        // 1. User has small window. Click Zoom -> Becomes Fit Width + Max Height.
        // 2. User has Fit Width window. Click Zoom -> Becomes Small Window.
        // 3. User Maximizes (Option+Green or Drag). Frame = Screen Size.
        //
        // The user said: "Make clicking the plus button... toggle between full window and fit to content."
        // This implies they want the Green Button to toggle between:
        // A: Fit Width (and presumably Max Height or current height?)
        // B: Full Window (Maximized Width and Height?)
        //
        // Standard "Zoom" logic doesn't easily support *three* states (User, Fit, Max).
        // It toggles between "User" and "Best".
        // If we define "Best" as "Fit Width + Max Height", then we get that.
        // But "Full Window" (Maximized Width) would be a separate manual action.
        
        // Let's assume "Full Window" = Maximize.
        // And "Fit to Content" = Fit Width.
        // If the window is currently Maximized (Full Screen-ish frame), and user clicks Zoom,
        // it should go to "Fit to Content".
        // If window is "Fit to Content", and user clicks Zoom, it should go to "Full Window".
        //
        // To implement this custom toggle logic, we might need to handle the button action manually
        // if `windowWillUseStandardFrame` mechanism isn't enough.
        // But `windowWillUseStandardFrame` is exactly for "Best Fit".
        // If I return the Fit Width frame here, then Zooming goes to it.
        // But how to get to "Full Window" (Maximized) if that is NOT the "Best Fit"?
        //
        // Maybe the user considers "Fit to content" as the "Standard State".
        // And "Full Window" as the "User State" (if they dragged it there)?
        //
        // Let's stick to the most useful NFO viewer behavior:
        // Zoom = Fit Width (and Max Height).
        // If user wants full screen width (empty space on sides), they can drag.
        //
        // Implementation: Return frame with ideal width and defaultFrame.height.
        
        var targetFrame = newFrame
        targetFrame.size.width = idealWidth
        
        // Ensure we don't exceed screen width (defaultFrame.width usually)
        if targetFrame.size.width > newFrame.size.width {
            targetFrame.size.width = newFrame.size.width
        }
        
        return targetFrame
    }
    
    func windowShouldZoom(_ window: NSWindow, toFrame newFrame: NSRect) -> Bool {
        // Implement custom toggle: Fit Width <-> Full Window (Maximize)
        guard let windowController = self.windowControllers.first,
              let viewController = windowController.contentViewController as? ViewController,
              let screen = window.screen else {
            return true
        }
        
        let contentWidth = viewController.calculateIdealContentWidth()
        // Convert content width to window width (accounting for borders/chrome)
        let fitWindowRect = window.frameRect(forContentRect: NSRect(x: 0, y: 0, width: contentWidth, height: 100))
        let fitWidth = fitWindowRect.width
        
        let currentFrame = window.frame
        let screenFrame = screen.visibleFrame
        
        // Check if we are currently "Full Window" (approximate)
        // We check if width is close to screen width
        let isMaximized = currentFrame.width >= screenFrame.width * 0.98
        
        // Check if we are currently "Fit to Width" (approximate)
        let isFitWidth = abs(currentFrame.width - fitWidth) < 20
        
        var targetFrame = window.frame
        
        // Logic:
        // If Fit -> Go Max
        // If Max -> Go Fit
        // If User (Neither) -> Go Fit
        
        if isFitWidth {
            // Toggle to Full Window
            targetFrame = screenFrame
        } else if isMaximized {
            // Toggle to Fit Width
            targetFrame.size.width = fitWidth
            // Keep current height (or should we maximize height too? User said "I don't want to force full height")
            // "I only wnat to resize content to the width."
            // So we keep current height, unless it's too small?
            // Let's keep current height, but ensure it fits screen vertically.
            // If coming from Max, current height is max height.
            // So effectively we just shrink width.
            
            // Re-center
            targetFrame.origin.x = screenFrame.minX + (screenFrame.width - targetFrame.width) / 2
        } else {
            // Toggle to Fit Width (from User size)
            targetFrame.size.width = fitWidth
            // Keep current height
            
            if targetFrame.size.width > screenFrame.width {
                targetFrame.size.width = screenFrame.width
            }
            
            // Re-center
            targetFrame.origin.x = screenFrame.minX + (screenFrame.width - targetFrame.width) / 2
        }
        
        window.setFrame(targetFrame, display: true, animate: true)
        
        return false // We handled the zoom manually
    }
}

