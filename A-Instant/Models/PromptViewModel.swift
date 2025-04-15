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
        
        let apiKey = UserDefaults.standard.string(forKey: selectedProvider.apiKeyUserDefaultsKey) ?? ""
        
        // System prompt with the text transformation instructions
        let systemPrompt = """
You are a text transformation AI.
Your task is to take a block of selected text and apply the given instruction to it.
Return only the modified text, with no explanations, no introductions, and no quotation marks.
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
                    // Extract a user-friendly error message
                    self?.error = (error as? AIServiceError)?.userFriendlyMessage ?? error.localizedDescription
                }
            },
            receiveValue: { [weak self] response in
                self?.replaceSelectedText(with: response)
            }
        )
        .store(in: &cancellables)
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
    
    func replaceSelectedText(with response: String) {
        // Copy the response to clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(response, forType: .string)
        
        // Dismiss the window
        if let window = NSApp.windows.first(where: { $0.isKeyWindow }) {
            window.close()
        }
        
        // Reactivate the original application and simulate paste
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            if let originalApp = self?.originalApplication {
                originalApp.activate()
                
                // Wait for the app to be activated before simulating paste
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self?.simulatePaste()
                }
            } else {
                // Fallback if no original app reference
                self?.simulatePaste()
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