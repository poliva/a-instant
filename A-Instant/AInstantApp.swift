import SwiftUI
import AppKit

@main
struct AInstantApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var settingsViewModel = SettingsViewModel()
    
    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(settingsViewModel)
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About A-Instant") {
                    NSApplication.shared.orderFrontStandardAboutPanel()
                }
            }
            
            CommandGroup(replacing: .newItem) {}
            
            CommandMenu("AI") {
                Button("Show Prompt Window") {
                    appDelegate.showPromptWindow()
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
            }
            
            CommandGroup(replacing: .appSettings) {
                Button("Settings...") {
                    appDelegate.openSettings()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
} 