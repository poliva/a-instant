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
            // Header with buttons
            HStack {
                Spacer()
                
                Button(action: {
                    showingSavedPrompts.toggle()
                }) {
                    Image(systemName: "list.bullet")
                        .resizable()
                        .frame(width: 20, height: 16)
                        .foregroundColor(.white.opacity(0.8))
                }
                .popover(isPresented: $showingSavedPrompts) {
                    savedPromptsView
                }
                
                Button(action: {
                    showingSavePromptSheet = true
                }) {
                    Image(systemName: "bookmark")
                        .resizable()
                        .frame(width: 16, height: 20)
                        .foregroundColor(.white.opacity(0.8))
                }
                .popover(isPresented: $showingSavePromptSheet) {
                    savePromptView
                }
            }
            .padding()
            .background(Color.black.opacity(0.3))
            
            Divider()
                .background(Color.gray)
            
            // Prompt input
            VStack(spacing: 10) {
                Text("What would you like to do?")
                    .font(.headline)
                    .foregroundColor(.white)
                
                // Display error if present
                if let errorMessage = viewModel.error {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.bottom, 5)
                        .multilineTextAlignment(.leading)
                }
                
                ScrollViewReader { proxy in
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $viewModel.promptText)
                            .font(.body)
                            .scrollContentBackground(.hidden)
                            .padding(8)
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(8)
                            .frame(minWidth: 350)
                            .frame(height: 80)
                            .id("textEditor")
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
                            .onChange(of: viewModel.promptText) { _, _ in
                                // Ensure we're always at the top when text changes
                                proxy.scrollTo("textEditor", anchor: .top)
                            }
                    }
                    .onAppear {
                        // Scroll to top when view appears
                        proxy.scrollTo("textEditor", anchor: .top)
                    }
                }
                
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
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(viewModel.promptText.isEmpty ? Color.gray : Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(viewModel.promptText.isEmpty || viewModel.isProcessing)
                }
            }
            .padding()
        }
        .background(Color(white: 0.15))
    }
    
    private var savedPromptsView: some View {
        VStack {
            Text("Saved Prompts")
                .font(.headline)
                .padding()
            
            if viewModel.savedPrompts.isEmpty {
                Text("No saved prompts yet")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                List {
                    ForEach(viewModel.savedPrompts) { prompt in
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