import Cocoa

@objc(Document)
class Document: NSDocument, NSWindowDelegate {
    
    var textContent: String = ""

    private let documentWindowFrameName = "DocumentWindow"
    private var liveResizeStartSize: NSSize?
    
    override class var autosavesInPlace: Bool {
        return false
    }

    override init() {
        super.init()
    }

    override func makeWindowControllers() {
        let viewController = ViewController()
        viewController.textContent = self.textContent
        
        let window = NSWindow(contentRect: NSMakeRect(0, 0, 800, 600),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered, defer: false)
        
        window.delegate = self
        
        let windowController = NSWindowController(window: window)
        windowController.contentViewController = viewController
        
        self.addWindowController(windowController)
        
        windowController.window?.title = self.displayName
        
        if !window.setFrameUsingName(documentWindowFrameName) {
            window.center()
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(preferencesDidChange(_:)),
            name: Constants.Notifications.preferencesChanged,
            object: nil
        )

        updateWindowSizePreference(window: window, viewController: viewController, animated: false)

        windowController.showWindow(self)
        window.makeKeyAndOrderFront(self)
    }

    @objc private func preferencesDidChange(_ notification: Notification) {
        let changes = PreferenceChange.changes(from: notification)
        let autoFitsWindow = UserDefaults.standard.bool(forKey: Constants.Defaults.autoFitWindowSize)
        guard changes.contains(.windowSizing)
                || (changes.contains(.contentMetrics) && autoFitsWindow) else {
            return
        }

        DispatchQueue.main.async { [weak self] in
            self?.updateWindowSizePreference(animated: true)
        }
    }

    private func updateWindowSizePreference(animated: Bool) {
        guard let windowController = windowControllers.first,
              let window = windowController.window,
              let viewController = windowController.contentViewController as? ViewController else {
            return
        }

        updateWindowSizePreference(window: window, viewController: viewController, animated: animated)
    }

    private func updateWindowSizePreference(
        window: NSWindow,
        viewController: ViewController,
        animated: Bool
    ) {
        let automaticallyFitsWindow = UserDefaults.standard.bool(forKey: Constants.Defaults.autoFitWindowSize)

        if !automaticallyFitsWindow {
            if window.frameAutosaveName != documentWindowFrameName {
                window.setFrameAutosaveName(documentWindowFrameName)
            }
            return
        }

        if !window.frameAutosaveName.isEmpty {
            window.setFrameAutosaveName("")
        }

        fitWindowToContent(window, viewController: viewController, animated: animated)
    }

    private func fitWindowToContent(
        _ window: NSWindow,
        viewController: ViewController,
        animated: Bool
    ) {
        guard let targetFrame = autoFitFrame(for: window, viewController: viewController),
              !NFOLayoutPolicy.framesAreApproximatelyEqual(window.frame, targetFrame) else { return }

        window.setFrame(targetFrame, display: true, animate: animated && window.isVisible)
    }

    private func autoFitFrame(
        for window: NSWindow,
        viewController: ViewController
    ) -> NSRect? {
        guard let screen = window.screen ?? NSScreen.main else { return nil }

        let contentSize = viewController.calculateIdealContentSize()
        let idealWindowFrame = window.frameRect(
            forContentRect: NSRect(origin: .zero, size: contentSize)
        )
        return NFOLayoutPolicy.autoFitFrame(
            idealWindowSize: idealWindowFrame.size,
            currentFrame: window.frame,
            visibleFrame: screen.visibleFrame
        )
    }

    override func read(from data: Data, ofType typeName: String) throws {
        textContent = try NFOContentDecoder.decode(data)
    }
    
    override func prepareSavePanel(_ savePanel: NSSavePanel) -> Bool {
        savePanel.isExtensionHidden = false
        return true
    }
    
    override func data(ofType typeName: String) throws -> Data {
        return textContent.data(using: .utf8) ?? Data()
    }
    
    // MARK: - NSWindowDelegate

    func windowWillStartLiveResize(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        liveResizeStartSize = window.frame.size
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        defer { liveResizeStartSize = nil }

        guard let window = notification.object as? NSWindow,
              let startSize = liveResizeStartSize,
              UserDefaults.standard.bool(forKey: Constants.Defaults.autoFitWindowSize),
              abs(window.frame.width - startSize.width) >= NFOLayoutPolicy.frameComparisonTolerance
                || abs(window.frame.height - startSize.height) >= NFOLayoutPolicy.frameComparisonTolerance else {
            return
        }

        UserDefaults.standard.set(false, forKey: Constants.Defaults.autoFitWindowSize)
        if window.frameAutosaveName != documentWindowFrameName {
            window.setFrameAutosaveName(documentWindowFrameName)
        }
        ThemeManager.shared.notifyPreferencesChanged([.windowSizing])
    }
    
    func windowShouldZoom(_ window: NSWindow, toFrame _: NSRect) -> Bool {
        guard let windowController = self.windowControllers.first,
              let viewController = windowController.contentViewController as? ViewController,
              let screen = window.screen else {
            return true
        }

        let screenFrame = screen.visibleFrame
        let targetFrame: NSRect

        if UserDefaults.standard.bool(forKey: Constants.Defaults.autoFitWindowSize),
           let automaticFrame = autoFitFrame(for: window, viewController: viewController) {
            targetFrame = NFOLayoutPolicy.framesAreApproximatelyEqual(window.frame, automaticFrame)
                ? screenFrame
                : automaticFrame
        } else {
            let contentWidth = viewController.calculateIdealContentWidth()
            let fitWindowRect = window.frameRect(
                forContentRect: NSRect(x: 0, y: 0, width: contentWidth, height: 100)
            )
            let fitWidth = min(
                max(fitWindowRect.width, NFOLayoutPolicy.minimumWindowDimension),
                screenFrame.width
            )
            let isFitWidth = abs(window.frame.width - fitWidth) < NFOLayoutPolicy.frameComparisonTolerance

            if isFitWidth {
                targetFrame = screenFrame
            } else {
                var fitFrame = window.frame
                fitFrame.size.width = fitWidth
                fitFrame.origin.x = screenFrame.minX + (screenFrame.width - fitWidth) / 2
                targetFrame = fitFrame
            }
        }

        window.setFrame(targetFrame, display: true, animate: true)
        return false
    }
}
