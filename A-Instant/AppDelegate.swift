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
    private var updateChecker = UpdateChecker()
    
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
        
        // Set up update checking
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            // Initial check is performed in checkForUpdates
            self?.checkForUpdates()
            
            // Start periodic checks after the initial check
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.setupPeriodicUpdateChecks()
            }
        }
        
        // Register for update notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUpdateAvailableNotification(_:)),
            name: Notification.Name("UpdateAvailableNotification"),
            object: nil
        )
        
        // Register for automatic updates setting change
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAutomaticUpdatesSettingChanged(_:)),
            name: Notification.Name("UpdateAutomaticUpdatesSettingChanged"),
            object: nil
        )
        
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
        updateChecker.stopPeriodicChecks()
        
        // Remove all notification observers
        NotificationCenter.default.removeObserver(self)
        
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
        
        menu.addItem(NSMenuItem(title: "Settings", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Show Debug Logs", action: #selector(showDebugLogs), keyEquivalent: "d"))
        menu.addItem(NSMenuItem.separator())
        
        menu.addItem(NSMenuItem(title: "Check for Updates", action: #selector(checkForUpdatesFromMenu), keyEquivalent: "u"))
        menu.addItem(NSMenuItem(title: "A-Instant GitHub", action: #selector(openGitHubRepository), keyEquivalent: "g"))
        menu.addItem(NSMenuItem.separator())
        
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
    }
    
    @objc func showPromptWindowFromMenu() {
        Logger.shared.log("Show prompt window triggered from menu")
        
        // Check if text is selected before showing the prompt window
        if let selectedText = pasteboardManager.captureSelectedText() {
            showPromptWindow(selectedText: selectedText)
        } else {
            // Only show the alert when triggered from menu
            Logger.shared.log("No text selected error (menu trigger)")
            showNoTextSelectedAlert()
        }
    }
    
    @objc func showPromptWindow(selectedText: String? = nil) {
        Logger.shared.log("Attempting to show prompt window")
        // Use provided text or try to capture selected text
        let textToUse: String?
        if let selectedText = selectedText {
            textToUse = selectedText
        } else if let capturedText = pasteboardManager.captureSelectedText() {
            textToUse = capturedText
        } else {
            // No text selected and not showing alert here
            // Logger.shared.log("No text selected (keyboard trigger)")
            return
        }
        
        Logger.shared.log("Selected text captured: \(textToUse!.prefix(30))...")
        // Get the frontmost application before showing our window
        let frontmostApp = NSWorkspace.shared.frontmostApplication
        
        if promptWindowController == nil {
            promptWindowController = PromptWindowController()
            Logger.shared.log("Created new prompt window controller")
        }
        
        if let controller = promptWindowController as? PromptWindowController {
            controller.showWindow(with: textToUse!, frontmostApp: frontmostApp)
            Logger.shared.log("Displayed prompt window")
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
        window.isReleasedWhenClosed = false
        
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
            UserDefaultsKeys.enableAutomaticUpdates: true,
            UserDefaultsKeys.enableDebugLogging: false,
            "isFirstLaunch": true
        ]
        
        UserDefaults.standard.register(defaults: defaults)
        Logger.shared.log("Default settings registered")
    }
    
    @objc func checkForUpdatesFromMenu() {
        Logger.shared.log("Check for updates triggered from menu")
        checkForUpdates(showNoUpdatesAlert: true)
    }
    
    private func checkForUpdates(showNoUpdatesAlert: Bool = false) {
        updateChecker.checkForUpdates { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let url):
                if let updateURL = url {
                    self.showUpdateAvailableAlert(updateURL: updateURL)
                } else if showNoUpdatesAlert {
                    self.showNoUpdatesAlert()
                }
            case .failure(let error):
                Logger.shared.log("Update check failed: \(error.localizedDescription)")
                // Only show error for manual checks
                if showNoUpdatesAlert {
                    self.showUpdateErrorAlert(error: error)
                }
            }
        }
    }
    
    private func showUpdateAvailableAlert(updateURL: URL) {
        let alert = NSAlert()
        alert.messageText = "A new version of A-Instant is available."
        
        // Get current and new version if possible
        if let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            let newVersion = updateURL.lastPathComponent.replacingOccurrences(of: "v", with: "")
            alert.informativeText = "Version \(newVersion) is available. You have \(currentVersion)."
        } else {
            alert.informativeText = "A newer version is available on GitHub."
        }
        
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Download Update")
        alert.addButton(withTitle: "Later")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            NSWorkspace.shared.open(updateURL)
            Logger.shared.log("Opening update URL: \(updateURL)")
        }
    }
    
    private func showNoUpdatesAlert() {
        let alert = NSAlert()
        alert.messageText = "You're up to date!"
        alert.informativeText = "A-Instant is currently on the latest version."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    private func showNoTextSelectedAlert() {
        let alert = NSAlert()
        alert.messageText = "No Text Selected"
        alert.informativeText = "Please select some text before using A-Instant."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    private func showUpdateErrorAlert(error: Error) {
        let alert = NSAlert()
        alert.messageText = "Update Check Failed"
        alert.informativeText = "Could not check for updates. \(error.localizedDescription)"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    private func setupPeriodicUpdateChecks() {
        // Check if automatic updates are enabled
        let automaticUpdatesEnabled = UserDefaults.standard.bool(forKey: UserDefaultsKeys.enableAutomaticUpdates)
        
        if automaticUpdatesEnabled {
            Logger.shared.log("Setting up periodic update checks")
            updateChecker.startPeriodicChecks()
        } else {
            Logger.shared.log("Automatic update checks are disabled")
            updateChecker.stopPeriodicChecks()
        }
    }
    
    @objc private func handleUpdateAvailableNotification(_ notification: Notification) {
        guard let updateURL = notification.userInfo?["updateURL"] as? URL else {
            Logger.shared.log("Update notification received but no URL found")
            return
        }
        
        Logger.shared.log("Update notification received with URL: \(updateURL)")
        showUpdateAvailableAlert(updateURL: updateURL)
    }
    
    @objc private func handleAutomaticUpdatesSettingChanged(_ notification: Notification) {
        // Handle automatic updates setting change
        Logger.shared.log("Automatic updates setting changed")
        setupPeriodicUpdateChecks()
    }
    
    @objc func openGitHubRepository() {
        Logger.shared.log("Opening GitHub repository")
        if let url = URL(string: "https://github.com/poliva/a-instant") {
            NSWorkspace.shared.open(url)
        }
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