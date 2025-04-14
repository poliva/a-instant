import AppKit
import SwiftUI
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem?
    private var keyboardMonitor: KeyboardMonitor?
    private var promptWindowController: Any?
    private let pasteboardManager = PasteboardManager()
    private var preferencesWindow: NSWindow?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
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
    }
    
    private func checkAccessibilityPermissions() {
        // First check without prompting
        if !AXIsProcessTrusted() {
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
            }
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        keyboardMonitor?.stopMonitoring()
    }
    
    private func setupStatusBarItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "text.cursor", accessibilityDescription: "A-Instant")
            button.action = #selector(statusBarButtonClicked(_:))
        }
    }
    
    @objc private func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        let menu = NSMenu()
        
        menu.addItem(NSMenuItem(title: "Show Prompt Window", action: #selector(showPromptWindowFromMenu), keyEquivalent: "p"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Settings", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
    }
    
    @objc func showPromptWindowFromMenu() {
        showPromptWindow()
    }
    
    @objc func showPromptWindow() {
        // Capture selected text using the pasteboard manager
        if let selectedText = pasteboardManager.captureSelectedText() {
            // Get the frontmost application before showing our window
            let frontmostApp = NSWorkspace.shared.frontmostApplication
            
            if #available(macOS 14.0, *) {
                if promptWindowController == nil {
                    promptWindowController = PromptWindowController()
                }
                
                if let controller = promptWindowController as? PromptWindowController {
                    controller.showWindow(with: selectedText, frontmostApp: frontmostApp)
                }
            } else {
                // Show a notification that macOS 14+ is required
                let content = UNMutableNotificationContent()
                content.title = "A-Instant"
                content.body = "macOS 14 or later is required to use this feature"
                
                let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
                UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
            }
        } else {
            // Show an error notification if no text is selected
            let content = UNMutableNotificationContent()
            content.title = "A-Instant"
            content.body = "No text selected"
            
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
        }
    }
    
    @objc func openSettings() {
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
        keyboardMonitor = KeyboardMonitor()
        keyboardMonitor?.onTriggerKeyDetected = { [weak self] in
            print("Trigger key detected, showing prompt window")
            DispatchQueue.main.async {
                self?.showPromptWindow()
            }
        }
        
        // Start the keyboard monitoring
        keyboardMonitor?.startMonitoring()
        
        // Log the current trigger key setting
        let keyString = UserDefaults.standard.string(forKey: UserDefaultsKeys.triggerKey) ?? "default"
        print("Current trigger key setting: \(keyString)")
    }
    
    private func registerDefaultSettings() {
        let defaults: [String: Any] = [
            UserDefaultsKeys.triggerKey: TriggerKey.rightShift.rawValue,
            UserDefaultsKeys.aiProvider: AIProvider.openAI.rawValue,
            UserDefaultsKeys.ollamaEndpoint: "http://localhost:11434",
            "isFirstLaunch": true
        ]
        
        UserDefaults.standard.register(defaults: defaults)
    }
    
    // MARK: - NSWindowDelegate
    
    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow, window == preferencesWindow {
            // Clear the reference when the window closes
            preferencesWindow = nil
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