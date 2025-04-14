import AppKit

class PasteboardManager {
    private let pasteboard = NSPasteboard.general
    private let simulateKeyPressQueue = DispatchQueue(label: "com.a-instant.clipboard", qos: .userInitiated)
    
    func captureSelectedText() -> String? {
        Logger.shared.log("Capturing selected text")
        // Preserve the current pasteboard contents
        let preservedPasteboard = PreservedPasteboard()
        
        // Clear pasteboard first to ensure we don't get old content
        pasteboard.clearContents()
        
        // Simulate Cmd+C to copy selected text
        var selectedText: String?
        
        // Use a dispatch semaphore to wait for the copy operation
        let semaphore = DispatchSemaphore(value: 0)
        
        simulateKeyPressQueue.async {
            Logger.shared.log("Simulating copy key press")
            self.simulateCopyKeyPress()
            
            // Wait a bit for the copy to happen
            Thread.sleep(forTimeInterval: 0.1)
            
            // Get the text from the pasteboard
            selectedText = self.pasteboard.string(forType: .string)
            
            if selectedText != nil {
                Logger.shared.log("Text captured: \(selectedText!.prefix(30))...")
            } else {
                Logger.shared.log("No text was captured")
            }
            
            semaphore.signal()
        }
        
        // Wait with a timeout to prevent hanging
        let _ = semaphore.wait(timeout: .now() + 0.5)
        
        // Restore original pasteboard contents
        preservedPasteboard.restore()
        Logger.shared.log("Original pasteboard contents restored")
        
        return selectedText
    }
    
    private func simulateCopyKeyPress() {
        // Create a Cmd+C key press
        let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(0x08), keyDown: true)
        keyDownEvent?.flags = .maskCommand
        keyDownEvent?.post(tap: .cghidEventTap)
        
        // And release
        let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(0x08), keyDown: false)
        keyUpEvent?.post(tap: .cghidEventTap)
    }
}

class PreservedPasteboard {
    private let pasteboard = NSPasteboard.general
    private var preservedItems: [NSPasteboardItem] = []
    
    init() {
        preserveContents()
    }
    
    private func preserveContents() {
        // Make deep copies of all pasteboard items
        preservedItems = pasteboard.pasteboardItems?.compactMap { item -> NSPasteboardItem? in
            let newItem = NSPasteboardItem()
            
            // Copy each type of data
            for type in item.types {
                if let data = item.data(forType: type) {
                    newItem.setData(data, forType: type)
                }
            }
            
            return newItem
        } ?? []
        
        Logger.shared.log("Preserved \(preservedItems.count) items from pasteboard")
    }
    
    func restore() {
        // We need to use a lock or dispatch queue to ensure thread safety
        DispatchQueue.main.async {
            self.pasteboard.clearContents()
            
            if !self.preservedItems.isEmpty {
                self.pasteboard.writeObjects(self.preservedItems)
                Logger.shared.log("Restored \(self.preservedItems.count) items to pasteboard")
            } else {
                Logger.shared.log("No items to restore to pasteboard")
            }
        }
    }
} 