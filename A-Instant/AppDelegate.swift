import AppKit
import SwiftUI
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem?
    private var keyboardMonitor: KeyboardMonitor?
    private var promptWindowController: Any?
    private let pasteboardManager = PasteboardManager()
    private var preferencesWindow: NSWindow?
    private var logViewerWindow: NSWindow?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize logger and log app start
        Logger.shared.log("Application started")
        
        setupStatusBarItem()
        
        // Close any automatically created windows
        NSApplication.shared.windows.forEach { window in
            if window.title.isEmpty && window.contentView?.subviews.isEmpty ?? true {
                window.close()
            }
        }
        
        // Set the activation policy to accessory to prevent dock icon
        NSApplication.shared.setActivationPolicy(.accessory)
        
        // Request notification permission
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { _, _ in }
        
        // Register default settings if they don't exist
        registerDefaultSettings()
        
        // Check for accessibility permissions
        checkAccessibilityPermissions()
        
        // Start keyboard monitoring after a short delay to avoid early crashes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.setupKeyboardMonitoring()
        }
        
        // Check if this is the first launch and open settings if it is
        if UserDefaults.standard.bool(forKey: "isFirstLaunch") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.openSettings()
                UserDefaults.standard.set(false, forKey: "isFirstLaunch")
            }
        }
        
        Logger.shared.log("Application initialization complete")
    }
    
    private func checkAccessibilityPermissions() {
        // First check without prompting
        if !AXIsProcessTrusted() {
            Logger.shared.log("Accessibility permissions not granted")
            // Only now show the prompt if needed
            let alert = NSAlert()
            alert.messageText = "Accessibility Permissions Required"
            alert.informativeText = "A-Instant needs accessibility permissions to monitor keyboard input and manipulate text. Please grant permissions in System Settings > Privacy & Security > Accessibility."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open Settings")
            alert.addButton(withTitle: "Later")
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                let prefPaneURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                NSWorkspace.shared.open(prefPaneURL)
                Logger.shared.log("Opened accessibility permissions settings")
            }
        } else {
            Logger.shared.log("Accessibility permissions already granted")
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        keyboardMonitor?.stopMonitoring()
        Logger.shared.log("Application terminating")
    }
    
    private func setupStatusBarItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "text.cursor", accessibilityDescription: "A-Instant")
            button.action = #selector(statusBarButtonClicked(_:))
        }
        Logger.shared.log("Status bar item setup complete")
    }
    
    @objc private func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        let menu = NSMenu()
        
        menu.addItem(NSMenuItem(title: "Show Prompt Window", action: #selector(showPromptWindowFromMenu), keyEquivalent: "p"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Settings", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Show Debug Logs", action: #selector(showDebugLogs), keyEquivalent: "d"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
    }
    
    @objc func showPromptWindowFromMenu() {
        Logger.shared.log("Show prompt window triggered from menu")
        showPromptWindow()
    }
    
    @objc func showPromptWindow() {
        Logger.shared.log("Attempting to show prompt window")
        // Capture selected text using the pasteboard manager
        if let selectedText = pasteboardManager.captureSelectedText() {
            Logger.shared.log("Selected text captured: \(selectedText.prefix(30))...")
            // Get the frontmost application before showing our window
            let frontmostApp = NSWorkspace.shared.frontmostApplication
            
            if #available(macOS 14.0, *) {
                if promptWindowController == nil {
                    promptWindowController = PromptWindowController()
                    Logger.shared.log("Created new prompt window controller")
                }
                
                if let controller = promptWindowController as? PromptWindowController {
                    controller.showWindow(with: selectedText, frontmostApp: frontmostApp)
                    Logger.shared.log("Displayed prompt window")
                }
            } else {
                // Show a notification that macOS 14+ is required
                Logger.shared.log("macOS 14+ required notification shown")
                let content = UNMutableNotificationContent()
                content.title = "A-Instant"
                content.body = "macOS 14 or later is required to use this feature"
                
                let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
                UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
            }
        } else {
            // Show an error notification if no text is selected
            Logger.shared.log("No text selected error")
            let content = UNMutableNotificationContent()
            content.title = "A-Instant"
            content.body = "No text selected"
            
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
        }
    }
    
    @objc func showDebugLogs() {
        Logger.shared.log("Show debug logs menu item clicked")
        
        // Check if window already exists
        if let window = logViewerWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        // Create a text view to display logs
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        textView.isEditable = false
        textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        
        // Get log content
        let logContent = Logger.shared.getLogFileContents()
        textView.string = logContent
        
        // Add text view to scroll view
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        
        // Create buttons
        let refreshButton = NSButton(title: "Refresh", target: self, action: #selector(refreshLogs))
        refreshButton.setFrameSize(NSSize(width: 80, height: 30))
        
        let openInFinderButton = NSButton(title: "Show in Finder", target: self, action: #selector(openLogsInFinder))
        openInFinderButton.setFrameSize(NSSize(width: 120, height: 30))
        
        let clearLogsButton = NSButton(title: "Clear Logs", target: self, action: #selector(clearLogs))
        clearLogsButton.setFrameSize(NSSize(width: 100, height: 30))
        
        // Create a container for buttons
        let buttonContainer = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 40))
        buttonContainer.addSubview(refreshButton)
        buttonContainer.addSubview(openInFinderButton)
        buttonContainer.addSubview(clearLogsButton)
        
        // Position buttons
        refreshButton.frame.origin = NSPoint(x: 10, y: 5)
        openInFinderButton.frame.origin = NSPoint(x: 100, y: 5)
        clearLogsButton.frame.origin = NSPoint(x: 230, y: 5)
        
        // Create main container view
        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 640))
        containerView.addSubview(scrollView)
        containerView.addSubview(buttonContainer)
        
        // Position subviews
        scrollView.frame.origin = NSPoint(x: 0, y: 40)
        buttonContainer.frame.origin = NSPoint(x: 0, y: 0)
        
        // Create window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Debug Logs"
        window.contentView = containerView
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.delegate = self
        
        NSApp.activate(ignoringOtherApps: true)
        
        // Store reference
        logViewerWindow = window
        
        // Scroll to end
        textView.scrollToEndOfDocument(nil)
        
        Logger.shared.log("Debug log viewer opened")
    }
    
    @objc func refreshLogs() {
        Logger.shared.log("Refreshing log view")
        guard let window = logViewerWindow,
              let containerView = window.contentView,
              let scrollView = containerView.subviews.first(where: { $0 is NSScrollView }) as? NSScrollView,
              let textView = scrollView.documentView as? NSTextView else {
            return
        }
        
        // Update log content
        textView.string = Logger.shared.getLogFileContents()
        textView.scrollToEndOfDocument(nil)
    }
    
    @objc func openLogsInFinder() {
        Logger.shared.log("Opening logs in Finder")
        let logURL = Logger.shared.getLogFileURL()
        NSWorkspace.shared.activateFileViewerSelecting([logURL])
    }
    
    @objc func clearLogs() {
        Logger.shared.log("Clearing logs")
        
        // Show confirmation alert
        let alert = NSAlert()
        alert.messageText = "Clear Debug Logs"
        alert.informativeText = "Are you sure you want to clear all debug logs? This action cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Clear Logs")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            Logger.shared.clearLogs()
            refreshLogs()
        }
    }
    
    @objc func openSettings() {
        Logger.shared.log("Opening settings window")
        // Check if a settings window is already open
        for window in NSApplication.shared.windows where window.title == "Settings" {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        // If we have a stored reference, reuse it
        if let window = preferencesWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        // Create a new settings window
        let settingsView = SettingsView()
            .environmentObject(SettingsViewModel())
        
        let controller = NSHostingController(rootView: settingsView)
        let window = NSWindow(contentViewController: controller)
        window.title = "Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.center()
        window.delegate = self
        window.level = .floating
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        // Store the reference
        preferencesWindow = window
    }
    
    @objc func showPreferencesWindow(_ sender: Any?) {
        openSettings()
    }
    
    private func setupKeyboardMonitoring() {
        Logger.shared.log("Setting up keyboard monitoring")
        keyboardMonitor = KeyboardMonitor()
        keyboardMonitor?.onTriggerKeyDetected = { [weak self] in
            Logger.shared.log("Trigger key detected, showing prompt window")
            DispatchQueue.main.async {
                self?.showPromptWindow()
            }
        }
        
        // Start the keyboard monitoring
        keyboardMonitor?.startMonitoring()
        
        // Log the current trigger key setting
        let keyString = UserDefaults.standard.string(forKey: UserDefaultsKeys.triggerKey) ?? "default"
        Logger.shared.log("Current trigger key setting: \(keyString)")
    }
    
    private func registerDefaultSettings() {
        let defaults: [String: Any] = [
            UserDefaultsKeys.triggerKey: TriggerKey.rightShift.rawValue,
            UserDefaultsKeys.aiProvider: AIProvider.openAI.rawValue,
            UserDefaultsKeys.ollamaEndpoint: "http://localhost:11434",
            UserDefaultsKeys.autoLaunchOnStartup: true,
            "isFirstLaunch": true
        ]
        
        UserDefaults.standard.register(defaults: defaults)
        Logger.shared.log("Default settings registered")
    }
    
    // MARK: - NSWindowDelegate
    
    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
            if window == preferencesWindow {
                // Clear the reference when the window closes
                preferencesWindow = nil
                Logger.shared.log("Preferences window closed")
            } else if window == logViewerWindow {
                // Clear the reference when the window closes
                logViewerWindow = nil
                Logger.shared.log("Log viewer window closed")
            }
        }
    }
}

extension NSApplication {
    func openSettingsWindow() {
        // First try to find the AppDelegate
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.showPreferencesWindow(nil)
        }
    }
} 