import Foundation
import SwiftUI
import Combine
import AppKit

class PromptViewModel: ObservableObject {
    @Published var selectedText: String
    @Published var promptText: String = ""
    @Published var isProcessing: Bool = false
    @Published var error: String? = nil
    @Published var savedPrompts: [SavedPrompt] = []
    @Published var promptSearchText: String = ""
    @Published var aiResponse: String = ""
    @Published var nonDestructiveMode: Bool = false
    @Published var showResponseView: Bool = false
    @Published var textReplaceAttemptFailed: Bool = false
    
    // Provider and model selection
    @Published var selectedProvider: AIProvider
    @Published var selectedModel: String = ""
    @Published var availableProviders: [AIProvider] = []
    @Published var availableModels: [String] = []
    
    // Filtered prompts based on search text
    var filteredSavedPrompts: [SavedPrompt] {
        if promptSearchText.isEmpty {
            return savedPrompts
        } else {
            return savedPrompts.filter { prompt in
                prompt.name.localizedCaseInsensitiveContains(promptSearchText) ||
                prompt.promptText.localizedCaseInsensitiveContains(promptSearchText)
            }
        }
    }
    
    private let aiService = AIService()
    private var cancellables = Set<AnyCancellable>()
    private var originalApplication: NSRunningApplication?
    
    init(selectedText: String, originalApplication: NSRunningApplication?) {
        self.selectedText = selectedText
        self.originalApplication = originalApplication
        
        // Initialize provider/model settings
        let providerString = UserDefaults.standard.string(forKey: UserDefaultsKeys.aiProvider) ?? AIProvider.openAI.rawValue
        self.selectedProvider = AIProvider.allCases.first { $0.rawValue == providerString } ?? .openAI
        
        // Load saved prompts
        loadSavedPrompts()
        
        // Load available providers and models
        loadAvailableProviders()
        loadModelsForCurrentProvider()
        
        // Load non-destructive mode setting
        nonDestructiveMode = UserDefaults.standard.bool(forKey: UserDefaultsKeys.nonDestructiveMode)
    }
    
    // Load all providers that have at least one model configured
    func loadAvailableProviders() {
        availableProviders = AIProvider.allCases.filter { provider in
            let modelKey = provider.modelUserDefaultsKey
            let apiKey = provider.apiKeyUserDefaultsKey
            return UserDefaults.standard.string(forKey: modelKey) != nil && 
                   UserDefaults.standard.string(forKey: apiKey) != nil &&
                   !UserDefaults.standard.string(forKey: apiKey)!.isEmpty
        }
    }
    
    // Load available models for the current provider
    func loadModelsForCurrentProvider() {
        let modelKey = selectedProvider.modelUserDefaultsKey
        if let model = UserDefaults.standard.string(forKey: modelKey) {
            selectedModel = model
        } else {
            selectedModel = ""
        }
        
        // Load models from cache
        loadCachedModels()
    }
    
    // Load models from the cache
    private func loadCachedModels() {
        let cacheKey = selectedProvider.cachedModelsUserDefaultsKey
        if let data = UserDefaults.standard.data(forKey: cacheKey) {
            do {
                let models = try JSONDecoder().decode([String].self, from: data)
                availableModels = models
            } catch {
                Logger.shared.log("Error loading cached models: \(error)")
                availableModels = []
            }
        } else {
            availableModels = []
        }
    }
    
    // Change the selected provider and update available models
    func changeProvider(_ provider: AIProvider) {
        selectedProvider = provider
        
        // Save selection to user defaults
        UserDefaults.standard.set(provider.rawValue, forKey: UserDefaultsKeys.aiProvider)
        
        // Load the updated models list
        loadModelsForCurrentProvider()
    }
    
    // Change the selected model
    func changeModel(_ model: String) {
        selectedModel = model
        
        // Save selection to user defaults
        UserDefaults.standard.set(model, forKey: selectedProvider.modelUserDefaultsKey)
    }
    
    func sendPrompt() {
        guard !promptText.isEmpty else { return }
        
        isProcessing = true
        error = nil
        textReplaceAttemptFailed = false
        
        let apiKey = UserDefaults.standard.string(forKey: selectedProvider.apiKeyUserDefaultsKey) ?? ""
        
        // Choose the appropriate system prompt based on mode
        let systemPrompt = nonDestructiveMode 
            ? """
            You are a highly context-aware assistant.
            Analyze the selected text to understand its meaning and context.
            Provide a helpful, thoughtful response to the user's instruction.
            Be specific and reference the content directly when relevant.
            Return your output in plain text, without code formatting or markdown symbols, unless explicitly requested by the user.
            """
            : """
            You are a text transformation AI.
            Your task is to take a block of selected text and apply the given instruction to it.
            Return ONLY the modified text, with no explanations, no introductions, no lead-ins, no conversation, no placeholders, no surrounding quotes, and no quotation marks.
            """
        
        // User prompt with just the instruction and selected text
        let userPrompt = """
Instruction:
```
\(promptText)
```

Selected text:
```
 \(selectedText)
```
"""
        
        aiService.sendPrompt(
            text: userPrompt,
            systemPrompt: systemPrompt,
            provider: selectedProvider,
            model: selectedModel,
            apiKey: apiKey
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { [weak self] completion in
                self?.isProcessing = false
                
                if case .failure(let error) = completion {
                    self?.error = error.userFriendlyMessage
                }
            },
            receiveValue: { [weak self] response in
                guard let self = self else { return }
                
                if self.nonDestructiveMode {
                    self.aiResponse = response
                    self.showResponseView = true
                } else {
                    self.processAIResponse(response)
                }
            }
        )
        .store(in: &cancellables)
    }
    
    func processAIResponse(_ response: String) {
        // Keep the original response
        self.aiResponse = response
        
        // Try to replace text if not in non-destructive mode
        if !nonDestructiveMode {
            self.replaceSelectedText(with: response, completion: { success in
                // If replacement failed, show the response view
                if !success {
                    DispatchQueue.main.async {
                        self.showResponseView = true
                        self.textReplaceAttemptFailed = true
                    }
                }
            })
        } else {
            self.showResponseView = true
        }
    }
    
    func savePrompt(name: String) {
        guard !promptText.isEmpty else { return }
        
        let newPrompt = SavedPrompt(
            name: name,
            promptText: promptText
        )
        
        savedPrompts.append(newPrompt)
        saveSavedPrompts()
    }
    
    func usePrompt(_ prompt: SavedPrompt) {
        promptText = prompt.promptText
    }
    
    func replaceSelectedText(with response: String, completion: @escaping (Bool) -> Void = { _ in }) {
        // Copy the response to clipboard
        let pasteboard = NSPasteboard.general
        let initialContents = pasteboard.string(forType: .string)
        pasteboard.clearContents()
        pasteboard.setString(response, forType: .string)
        
        // Save the window reference before closing
        let window = NSApp.windows.first(where: { $0.isKeyWindow })
        
        // Store initial selected text
        let initialSelectedText = self.selectedText
        
        // Reactivate the original application and simulate paste
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            
            let activateAndPaste = {
                // Attempt to paste the text
                self.simulatePaste()
                
                // Check if paste worked by verifying text change
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    // Try to recapture selected text to see if it changed
                    let pasteManager = PasteboardManager()
                    let capturedTextAfterPaste = pasteManager.captureSelectedText()
                    let selectedTextChanged = capturedTextAfterPaste != initialSelectedText
                    
                    // Log the detection results
                    Logger.shared.log("Paste verification - Text changed: \(selectedTextChanged), Initial: \(initialSelectedText.prefix(20))..., After: \(capturedTextAfterPaste?.prefix(20) ?? "nil")...")
                    
                    // Only consider a failure when the selected text didn't change and there was non-empty text captured
                    let pasteFailed = !selectedTextChanged && capturedTextAfterPaste?.isEmpty == false
                    
                    if !pasteFailed {
                        // Consider paste successful
                        window?.close()
                        completion(true)
                    } else {
                        // Paste likely failed
                        Logger.shared.log("Paste operation likely failed")
                        // Restore original clipboard
                        if let originalContent = initialContents {
                            pasteboard.clearContents()
                            pasteboard.setString(originalContent, forType: .string)
                        }
                        completion(false)
                    }
                    
                    // In either case, restore clipboard after a delay to ensure paste completes
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        if let originalContent = initialContents {
                            pasteboard.clearContents()
                            pasteboard.setString(originalContent, forType: .string)
                            Logger.shared.log("Restored original clipboard contents")
                        }
                    }
                }
            }
            
            // Activate original app if available, otherwise just paste
            if let originalApp = self.originalApplication {
                originalApp.activate()
                
                // Wait for the app to be activated before simulating paste
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    activateAndPaste()
                }
            } else {
                // Fallback if no original app reference
                activateAndPaste()
            }
        }
    }
    
    private func simulatePaste() {
        // Simulate Cmd+V to paste
        let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(0x09), keyDown: true)
        keyDownEvent?.flags = .maskCommand
        keyDownEvent?.post(tap: .cghidEventTap)
        
        let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(0x09), keyDown: false)
        keyUpEvent?.post(tap: .cghidEventTap)
    }
    
    private func loadSavedPrompts() {
        if let data = UserDefaults.standard.data(forKey: UserDefaultsKeys.savedPrompts) {
            do {
                savedPrompts = try JSONDecoder().decode([SavedPrompt].self, from: data)
            } catch {
                Logger.shared.log("Error loading saved prompts: \(error)")
                savedPrompts = []
            }
        }
    }
    
    private func saveSavedPrompts() {
        do {
            let data = try JSONEncoder().encode(savedPrompts)
            UserDefaults.standard.set(data, forKey: UserDefaultsKeys.savedPrompts)
        } catch {
            Logger.shared.log("Error saving prompts: \(error)")
        }
    }
} 