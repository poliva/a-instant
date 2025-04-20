import SwiftUI
import AppKit

@available(macOS 14.0, *)
struct CustomTextEditor: NSViewRepresentable {
    @Binding var text: String
    var isProcessing: Bool
    var onEnterKey: () -> Void
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView
        
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        textView.drawsBackground = false
        textView.isEditable = true
        textView.isSelectable = true
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        let textView = nsView.documentView as! NSTextView
        
        // Only update text if it has actually changed (to avoid cursor jumping)
        if textView.string != self.text {
            textView.string = self.text
        }
        
        // Update the state
        context.coordinator.text = $text
        context.coordinator.isProcessing = isProcessing
        context.coordinator.onEnterKey = onEnterKey
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, isProcessing: isProcessing, onEnterKey: onEnterKey)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        var isProcessing: Bool
        var onEnterKey: () -> Void
        
        init(text: Binding<String>, isProcessing: Bool, onEnterKey: @escaping () -> Void) {
            self.text = text
            self.isProcessing = isProcessing
            self.onEnterKey = onEnterKey
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            self.text.wrappedValue = textView.string
        }
        
        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            // Check for Return key press
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                // Check for shift key modifier
                if NSEvent.modifierFlags.contains(.shift) {
                    // Get cursor position
                    let selectedRange = textView.selectedRange
                    
                    // Insert newline at cursor position
                    let newText = (textView.string as NSString).replacingCharacters(
                        in: selectedRange,
                        with: "\n"
                    )
                    
                    // Update text
                    textView.string = newText
                    
                    // Move cursor after the inserted newline
                    let newPosition = selectedRange.location + 1
                    textView.setSelectedRange(NSRange(location: newPosition, length: 0))
                    
                    return true
                } else if !textView.string.isEmpty && !isProcessing {
                    // If Enter is pressed without Shift and text is not empty and not processing
                    onEnterKey()
                    return true
                }
            }
            
            return false
        }
    }
} 