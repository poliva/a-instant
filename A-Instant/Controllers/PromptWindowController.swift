import AppKit
import SwiftUI

@available(macOS 14.0, *)
class PromptWindowController: NSWindowController {
    private var selectedText: String = ""
    private var promptViewModel: PromptViewModel?
    private var originalApplication: NSRunningApplication?
    
    convenience init() {
        // Create the window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 550, height: 350),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        window.center()
        window.isReleasedWhenClosed = false
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.backgroundColor = NSColor(white: 0.1, alpha: 0.9)
        window.hasShadow = true
        window.level = .floating
        
        // Setup window appearance
        window.appearance = NSAppearance(named: .vibrantDark)
        window.collectionBehavior = [.canJoinAllSpaces, .participatesInCycle]
        
        // Add rounded corners
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.cornerRadius = 12
        window.contentView?.layer?.masksToBounds = true
        
        self.init(window: window)
        
        // Set delegate to monitor window close events
        window.delegate = self
    }
    
    func showWindow(with text: String, frontmostApp: NSRunningApplication?) {
        guard !text.isEmpty else {
            print("Warning: Attempted to show prompt window with empty text")
            return
        }
        
        selectedText = text
        originalApplication = frontmostApp
        
        // Create view model with selected text and original application
        promptViewModel = PromptViewModel(selectedText: selectedText, originalApplication: originalApplication)
        
        // Create and set the content view
        let contentView = PromptView(viewModel: promptViewModel!)
            .environment(\.colorScheme, .dark)
        
        let hostingController = NSHostingController(rootView: contentView)
        window?.contentViewController = hostingController
        
        // Show window safely on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let window = self.window else { return }
            
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            
            // Position window near mouse location
            self.positionWindowNearMouse()
        }
    }
    
    private func positionWindowNearMouse() {
        guard let screenFrame = NSScreen.main?.visibleFrame,
              let window = window else { return }
        
        let mouseLocation = NSEvent.mouseLocation
        
        // Adjust the window position to be near the mouse but fully visible
        var windowFrame = window.frame
        
        // Calculate optimal position (below the mouse cursor)
        var newOrigin = NSPoint(
            x: mouseLocation.x - windowFrame.width / 2,
            y: mouseLocation.y - windowFrame.height - 20
        )
        
        // Ensure window stays within screen bounds
        // Horizontal bounds
        newOrigin.x = max(newOrigin.x, screenFrame.minX + 20)
        newOrigin.x = min(newOrigin.x, screenFrame.maxX - windowFrame.width - 20)
        
        // If the window would be off-screen at the bottom, position it above the mouse
        if newOrigin.y < screenFrame.minY {
            newOrigin.y = mouseLocation.y + 20
        }
        
        // If it would now be off-screen at the top, adjust again
        if newOrigin.y + windowFrame.height > screenFrame.maxY {
            newOrigin.y = screenFrame.maxY - windowFrame.height - 20
        }
        
        windowFrame.origin = newOrigin
        window.setFrame(windowFrame, display: true, animate: true)
    }
}

// MARK: - NSWindowDelegate
@available(macOS 14.0, *)
extension PromptWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        // Clean up resources when window closes
        promptViewModel = nil
    }
} 