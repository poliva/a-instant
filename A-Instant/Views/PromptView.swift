import SwiftUI
import Combine

@available(macOS 14.0, *)
struct PromptView: View {
    @ObservedObject var viewModel: PromptViewModel
    @State private var showingSavedPrompts = false
    @State private var showingSavePromptSheet = false
    @State private var promptName = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Prompt input with dark minimalist design
            ZStack(alignment: .topTrailing) {
                // Text editor with placeholder
                TextEditor(text: $viewModel.promptText)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .background(Color.black)
                    .foregroundColor(.white)
                    .padding(12)
                    .padding(.trailing, 30) // Add padding to avoid overlapping with buttons
                    .frame(minWidth: 500, minHeight: 85) // Taller to fit 3 lines
                    .overlay(
                        ZStack(alignment: .topLeading) {
                            if viewModel.promptText.isEmpty {
                                Text("What would you like to do...")
                                    .foregroundColor(.gray)
                                    .padding(.horizontal, 16)
                                    .padding(.top, 14)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            }
                        }
                    )
                    .onKeyPress(keys: [.return]) { _ in
                        if NSEvent.modifierFlags.contains(.shift) {
                            viewModel.promptText += "\n"
                            return .handled
                        } else if !viewModel.promptText.isEmpty && !viewModel.isProcessing {
                            viewModel.sendPrompt()
                            return .handled
                        }
                        return .ignored
                    }
                
                // Header buttons in top right
                VStack(spacing: 15) {
                    Button(action: {
                        showingSavePromptSheet = true
                    }) {
                        Image(systemName: "bookmark")
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .popover(isPresented: $showingSavePromptSheet) {
                        savePromptView
                    }
                    
                    Button(action: {
                        showingSavedPrompts.toggle()
                    }) {
                        Image(systemName: "list.bullet")
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .popover(isPresented: $showingSavedPrompts) {
                        savedPromptsView
                    }
                    
                    Button(action: {
                        viewModel.nonDestructiveMode.toggle()
                        // Save the setting to UserDefaults
                        UserDefaults.standard.set(viewModel.nonDestructiveMode, forKey: UserDefaultsKeys.nonDestructiveMode)
                    }) {
                        Image(systemName: viewModel.nonDestructiveMode ? "arrow.down.square.fill" : "arrow.uturn.left.square")
                            .foregroundColor(viewModel.nonDestructiveMode ? .blue.opacity(0.9) : .white.opacity(0.8))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Toggle non-destructive mode: \(viewModel.nonDestructiveMode ? "On" : "Off")")
                }
                .padding(12)
            }
            
            // Display original text when in non-destructive mode and showing response
            if viewModel.nonDestructiveMode && viewModel.showResponseView {
                Divider()
                
                VStack(alignment: .leading) {
                    /*
                    Text("Selected Text:")
                        .font(.headline)
                        .foregroundColor(.gray)
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                    
                    ScrollView {
                        Text(viewModel.selectedText)
                            .font(.body)
                            .foregroundColor(.white)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 100)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(8)
                    .padding(.horizontal, 12)
                    */
                    
                    Text("Response:")
                        .font(.headline)
                        .foregroundColor(.gray)
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                    
                    ScrollView {
                        Text(viewModel.aiResponse)
                            .font(.body)
                            .foregroundColor(.white)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 250)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(8)
                    .padding(.horizontal, 12)
                    
                    HStack {
                        Spacer()
                        
                        Button(action: {
                            viewModel.showResponseView = false
                            viewModel.aiResponse = ""
                        }) {
                            Text("Clear")
                                .font(.headline)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.gray.opacity(0.5))
                                .foregroundColor(.white)
                                .cornerRadius(16)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Button(action: {
                            let pasteboard = NSPasteboard.general
                            pasteboard.clearContents()
                            pasteboard.setString(viewModel.aiResponse, forType: .string)
                        }) {
                            Text("Copy Response")
                                .font(.headline)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(16)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.horizontal, 8)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
            }
            
            // Bottom controls
            HStack(alignment: .center) {
                // Provider/Model selectors - only display if more than one provider configured
                if viewModel.availableProviders.count > 1 {
                    HStack(spacing: 8) {
                        // Provider selector
                        Text(viewModel.selectedProvider.rawValue)
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(Color.black)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                            .compactMenu {
                                ForEach(viewModel.availableProviders, id: \.self) { provider in
                                    Button(action: {
                                        viewModel.changeProvider(provider)
                                    }) {
                                        Text(provider.rawValue)
                                        if provider == viewModel.selectedProvider {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        
                        // Model selector
                        Text(viewModel.selectedModel)
                            .font(.system(size: 12))
                            .lineLimit(1)
                            .foregroundColor(.gray)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(Color.black)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                            .compactMenu {
                                if viewModel.availableModels.isEmpty {
                                    Text("Refresh models in settings to see available models")
                                } else {
                                    ForEach(viewModel.availableModels, id: \.self) { model in
                                        Button(action: {
                                            viewModel.changeModel(model)
                                        }) {
                                            Text(model)
                                            if model == viewModel.selectedModel {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            }
                    }
                } else {
                    // Just show selected model
                    Text(viewModel.selectedModel)
                        .foregroundColor(.gray)
                        .font(.system(size: 11))
                        .padding(.leading, 12)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Error display
                if let errorMessage = viewModel.error {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .lineLimit(1)
                }
                
                // Send button / processing indicator
                HStack {
                    if viewModel.isProcessing {
                        ProgressView()
                            .scaleEffect(0.8)
                            .padding(.trailing, 5)
                    }
                    
                    Button(action: {
                        viewModel.sendPrompt()
                    }) {
                        HStack {
                            Text("Send")
                                .font(.headline)
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 14))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(viewModel.promptText.isEmpty ? Color.gray.opacity(0.5) : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(viewModel.promptText.isEmpty || viewModel.isProcessing)
                    .padding(.trailing, 4) // Add extra padding on the right
                }
            }
            .padding(.horizontal, 16) // Increase horizontal padding
            .padding(.vertical, 8)
            .background(Color.black)
        }
        .background(Color.black)
        // Update window size when showing response in non-destructive mode
        .onChange(of: viewModel.showResponseView) { oldValue, newValue in
            if newValue && viewModel.nonDestructiveMode {
                resizeWindow(height: 520)
            } else if !newValue && viewModel.nonDestructiveMode {
                resizeWindow(height: 170)
            }
        }
    }
    
    private func resizeWindow(height: CGFloat) {
        if let windowScene = NSApplication.shared.windows.first(where: { $0.isKeyWindow }) {
            let newFrame = NSRect(
                x: windowScene.frame.origin.x,
                y: windowScene.frame.origin.y - (height - windowScene.frame.height),
                width: windowScene.frame.width, // Keep existing width
                height: height
            )
            windowScene.setFrame(newFrame, display: true, animate: true)
        }
    }
    
    private var savedPromptsView: some View {
        VStack {
            Text("Saved Prompts")
                .font(.headline)
                .padding()
            
            // Add search field
            TextField("Search prompts...", text: $viewModel.promptSearchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
                .padding(.bottom, 10)
            
            if viewModel.savedPrompts.isEmpty {
                Text("No saved prompts yet")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                List {
                    ForEach(viewModel.filteredSavedPrompts) { prompt in
                        Button(action: {
                            viewModel.usePrompt(prompt)
                            showingSavedPrompts = false
                        }) {
                            Text(prompt.name)
                                .foregroundColor(.primary)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.vertical, 4)
                    }
                }
                .frame(width: 300, height: 200)
            }
        }
        .frame(width: 300)
    }
    
    private var savePromptView: some View {
        VStack(spacing: 16) {
            Text("Save Prompt")
                .font(.headline)
            
            TextField("Prompt Name", text: $promptName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 300)
            
            HStack {
                Button("Cancel") {
                    promptName = ""
                    showingSavePromptSheet = false
                }
                
                Button("Save") {
                    if !promptName.isEmpty {
                        viewModel.savePrompt(name: promptName)
                        promptName = ""
                        showingSavePromptSheet = false
                    }
                }
                .disabled(promptName.isEmpty || viewModel.promptText.isEmpty)
            }
            .padding(.bottom, 8)
        }
        .padding()
        .frame(width: 350)
    }
}

// Helper extension to create a menu that only takes up the width it needs
@available(macOS 14.0, *)
extension View {
    func compactMenu<Content: View>(
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        Menu {
            content()
        } label: {
            self
        }
        .menuStyle(BorderlessButtonMenuStyle())
        .fixedSize(horizontal: true, vertical: false)
    }
} 