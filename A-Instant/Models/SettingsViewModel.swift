import Foundation
import Combine
import ServiceManagement

class SettingsViewModel: ObservableObject {
    @Published var selectedTriggerKey: TriggerKey = .rightShift
    @Published var selectedProvider: AIProvider = .openAI
    @Published var openAIKey: String = ""
    @Published var anthropicKey: String = ""
    @Published var googleKey: String = ""
    @Published var groqKey: String = ""
    @Published var deepSeekKey: String = ""
    @Published var mistralKey: String = ""
    @Published var ollamaEndpoint: String = "http://localhost:11434"
    @Published var autoLaunchOnStartup: Bool = true
    
    @Published var openAIModel: String = ""
    @Published var anthropicModel: String = ""
    @Published var googleModel: String = ""
    @Published var groqModel: String = ""
    @Published var deepSeekModel: String = ""
    @Published var mistralModel: String = ""
    @Published var ollamaModel: String = ""
    
    @Published var availableModels: [String] = []
    @Published var isLoadingModels: Bool = false
    @Published var modelLoadError: String? = nil
    @Published var savedPrompts: [SavedPrompt] = []
    @Published var promptSearchText: String = ""
    
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
    
    private var cancellables = Set<AnyCancellable>()
    private let aiService = AIService()
    
    init() {
        loadSettings()
    }
    
    func loadSettings() {
        // Load trigger key
        if let keyString = UserDefaults.standard.string(forKey: UserDefaultsKeys.triggerKey),
           let key = TriggerKey.allCases.first(where: { $0.rawValue == keyString }) {
            selectedTriggerKey = key
        }
        
        // Load selected provider
        if let providerString = UserDefaults.standard.string(forKey: UserDefaultsKeys.aiProvider),
           let provider = AIProvider.allCases.first(where: { $0.rawValue == providerString }) {
            selectedProvider = provider
        }
        
        // Load API keys
        openAIKey = UserDefaults.standard.string(forKey: UserDefaultsKeys.openAIKey) ?? ""
        anthropicKey = UserDefaults.standard.string(forKey: UserDefaultsKeys.anthropicKey) ?? ""
        googleKey = UserDefaults.standard.string(forKey: UserDefaultsKeys.googleKey) ?? ""
        groqKey = UserDefaults.standard.string(forKey: UserDefaultsKeys.groqKey) ?? ""
        deepSeekKey = UserDefaults.standard.string(forKey: UserDefaultsKeys.deepSeekKey) ?? ""
        mistralKey = UserDefaults.standard.string(forKey: UserDefaultsKeys.mistralKey) ?? ""
        ollamaEndpoint = UserDefaults.standard.string(forKey: UserDefaultsKeys.ollamaEndpoint) ?? "http://localhost:11434"
        
        // Load model selections
        openAIModel = UserDefaults.standard.string(forKey: UserDefaultsKeys.openAIModel) ?? ""
        anthropicModel = UserDefaults.standard.string(forKey: UserDefaultsKeys.anthropicModel) ?? ""
        googleModel = UserDefaults.standard.string(forKey: UserDefaultsKeys.googleModel) ?? ""
        groqModel = UserDefaults.standard.string(forKey: UserDefaultsKeys.groqModel) ?? ""
        deepSeekModel = UserDefaults.standard.string(forKey: UserDefaultsKeys.deepSeekModel) ?? ""
        mistralModel = UserDefaults.standard.string(forKey: UserDefaultsKeys.mistralModel) ?? ""
        ollamaModel = UserDefaults.standard.string(forKey: UserDefaultsKeys.ollamaModel) ?? ""
        
        // Load saved prompts
        if let data = UserDefaults.standard.data(forKey: UserDefaultsKeys.savedPrompts) {
            do {
                savedPrompts = try JSONDecoder().decode([SavedPrompt].self, from: data)
            } catch {
                Logger.shared.log("Error loading saved prompts: \(error)")
                savedPrompts = []
            }
        }
        
        // Add default prompts if none exist
        if savedPrompts.isEmpty {
            createDefaultPrompts()
        }
        
        // Load auto-launch setting, defaulting to true if not set
        autoLaunchOnStartup = UserDefaults.standard.object(forKey: UserDefaultsKeys.autoLaunchOnStartup) as? Bool ?? true
        
        // Apply auto-launch setting
        updateAutoLaunchStatus()
    }
    
    func saveSettings() {
        // Save trigger key
        UserDefaults.standard.set(selectedTriggerKey.rawValue, forKey: UserDefaultsKeys.triggerKey)
        
        // Save selected provider
        UserDefaults.standard.set(selectedProvider.rawValue, forKey: UserDefaultsKeys.aiProvider)
        
        // Save API keys
        UserDefaults.standard.set(openAIKey, forKey: UserDefaultsKeys.openAIKey)
        UserDefaults.standard.set(anthropicKey, forKey: UserDefaultsKeys.anthropicKey)
        UserDefaults.standard.set(googleKey, forKey: UserDefaultsKeys.googleKey)
        UserDefaults.standard.set(groqKey, forKey: UserDefaultsKeys.groqKey)
        UserDefaults.standard.set(deepSeekKey, forKey: UserDefaultsKeys.deepSeekKey)
        UserDefaults.standard.set(mistralKey, forKey: UserDefaultsKeys.mistralKey)
        UserDefaults.standard.set(ollamaEndpoint, forKey: UserDefaultsKeys.ollamaEndpoint)
        
        // Save model selections
        UserDefaults.standard.set(openAIModel, forKey: UserDefaultsKeys.openAIModel)
        UserDefaults.standard.set(anthropicModel, forKey: UserDefaultsKeys.anthropicModel)
        UserDefaults.standard.set(googleModel, forKey: UserDefaultsKeys.googleModel)
        UserDefaults.standard.set(groqModel, forKey: UserDefaultsKeys.groqModel)
        UserDefaults.standard.set(deepSeekModel, forKey: UserDefaultsKeys.deepSeekModel)
        UserDefaults.standard.set(mistralModel, forKey: UserDefaultsKeys.mistralModel)
        UserDefaults.standard.set(ollamaModel, forKey: UserDefaultsKeys.ollamaModel)
        
        // Save prompts
        do {
            let data = try JSONEncoder().encode(savedPrompts)
            UserDefaults.standard.set(data, forKey: UserDefaultsKeys.savedPrompts)
        } catch {
            Logger.shared.log("Error saving prompts: \(error)")
        }
        
        // Save auto-launch setting
        UserDefaults.standard.set(autoLaunchOnStartup, forKey: UserDefaultsKeys.autoLaunchOnStartup)
        
        // Apply auto-launch setting
        updateAutoLaunchStatus()
    }
    
    func refreshModelList() {
        isLoadingModels = true
        modelLoadError = nil
        
        let apiKey: String
        
        switch selectedProvider {
        case .openAI:
            apiKey = openAIKey
            if apiKey.isEmpty {
                modelLoadError = "Please enter your OpenAI API key in the API tab"
                isLoadingModels = false
                return
            }
        case .anthropic:
            apiKey = anthropicKey
            if apiKey.isEmpty {
                modelLoadError = "Please enter your Anthropic API key in the API tab"
                isLoadingModels = false
                return
            }
        case .google:
            apiKey = googleKey
            if apiKey.isEmpty {
                modelLoadError = "Please enter your Google API key in the API tab"
                isLoadingModels = false
                return
            }
        case .groq:
            apiKey = groqKey
            if apiKey.isEmpty {
                modelLoadError = "Please enter your Groq API key in the API tab"
                isLoadingModels = false
                return
            }
        case .deepSeek:
            apiKey = deepSeekKey
            if apiKey.isEmpty {
                modelLoadError = "Please enter your DeepSeek API key in the API tab"
                isLoadingModels = false
                return
            }
        case .mistral:
            apiKey = mistralKey
            if apiKey.isEmpty {
                modelLoadError = "Please enter your Mistral API key in the API tab"
                isLoadingModels = false
                return
            }
        case .ollama:
            apiKey = "" // Ollama doesn't use API keys
        }
        
        aiService.fetchModels(provider: selectedProvider, apiKey: apiKey)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoadingModels = false
                    
                    if case .failure(let error) = completion {
                        // Extract a user-friendly error message
                        if let apiError = error as? AIServiceError {
                            self?.modelLoadError = apiError.userFriendlyMessage
                        } else {
                            self?.modelLoadError = error.localizedDescription
                        }
                        self?.availableModels = []
                    }
                },
                receiveValue: { [weak self] models in
                    self?.availableModels = models
                }
            )
            .store(in: &cancellables)
    }
    
    var currentAPIKey: String {
        switch selectedProvider {
        case .openAI: return openAIKey
        case .anthropic: return anthropicKey
        case .google: return googleKey
        case .groq: return groqKey
        case .deepSeek: return deepSeekKey
        case .mistral: return mistralKey
        case .ollama: return "" // Ollama doesn't use API keys
        }
    }
    
    var currentModel: String {
        switch selectedProvider {
        case .openAI: return openAIModel
        case .anthropic: return anthropicModel
        case .google: return googleModel
        case .groq: return groqModel
        case .deepSeek: return deepSeekModel
        case .mistral: return mistralModel
        case .ollama: return ollamaModel
        }
    }
    
    // Make sure availableModels contains at least the current model
    var displayModels: [String] {
        if availableModels.isEmpty && !currentModel.isEmpty {
            return [currentModel]
        }
        return availableModels
    }
    
    func setCurrentModel(_ model: String) {
        switch selectedProvider {
        case .openAI:
            openAIModel = model
            UserDefaults.standard.set(model, forKey: UserDefaultsKeys.openAIModel)
        case .anthropic:
            anthropicModel = model
            UserDefaults.standard.set(model, forKey: UserDefaultsKeys.anthropicModel)
        case .google:
            googleModel = model
            UserDefaults.standard.set(model, forKey: UserDefaultsKeys.googleModel)
        case .groq:
            groqModel = model
            UserDefaults.standard.set(model, forKey: UserDefaultsKeys.groqModel)
        case .deepSeek:
            deepSeekModel = model
            UserDefaults.standard.set(model, forKey: UserDefaultsKeys.deepSeekModel)
        case .mistral:
            mistralModel = model
            UserDefaults.standard.set(model, forKey: UserDefaultsKeys.mistralModel)
        case .ollama:
            ollamaModel = model
            UserDefaults.standard.set(model, forKey: UserDefaultsKeys.ollamaModel)
        }
    }
    
    // Adds default prompt templates when no prompts exist
    private func createDefaultPrompts() {
        let defaultPrompts: [(name: String, instruction: String)] = [
            (
                "Add emojis",
                "Add fitting emojis at the end of key sentences or next to emotional words, but keep the overall tone natural. Do not overuse emojis or place them randomly."
            ),
            (
                "Translate to Catalan",
                "Translate the selected text into Catalan."
            ),
            (
                "Shorten for Twitter",
                "Condense the text so that it can be posted on Twitter (280 characters max). Prioritize keeping the original intent intact, but remove redundancy and fluff."
            ),
            (
                "Make it sound formal",
                "Rephrase the text in a professional and formal tone suitable for a workplace enviroment. Remove any slang or casual expressions."
            ),
            (
                "Make it a casual text",
                "Rewrite the selected text to sound like a modern, casual text message sent to a close friend. Include emojis and contractions as appropriate."
            ),
            (
                "Add light humor",
                "Add subtle humor to the text by inserting clever wordplay or light-hearted expressions. Do not change the meaning or make it into a joke."
            ),
            (
                "Work Email",
                "You are an assistant that transforms informal or unstructured text into a clear, professional work email. Follow these rules when rewriting:\n1. Preserve the speaker's original tone and personality.\n2. Maintain a professional tone while reflecting the user's natural speaking style.\n3. Structure content into clear, concise paragraphs.\n4. Correct grammar, spelling, and punctuation, while preserving meaning.\n5. Eliminate filler words and redundant phrases.\n6. Retain all important details, context, and information.\n7. Format any lists or bullet points cleanly and professionally.\n8. Preserve specific requests, questions, or action items.\n9. Add a professional sign-off (e.g., \"Thanks,\" \"Best regards,\" \"Cheers,\" etc.) as appropriate.\n10. Choose a greeting that fits the context and level of formality.\n\nOutput only the final, plain-text version of the email, ready to be copied and sent. Do not include explanations or formatting beyond the email itself."
            ),
            (
                "Work Chat",
                "You are a professional communication assistant.\nConvert the selected text into a concise, friendly, and professional message suitable for an internal work chat (like Slack, Microsoft Teams, or Mattermost).\nMaintain clarity, appropriate tone, and ensure the message fits a quick, collaborative workplace environment."
            )
        ]
        
        savedPrompts = defaultPrompts.map { promptInfo in
            SavedPrompt(
                name: promptInfo.name,
                promptText: promptInfo.instruction
            )
        }
        
        // Save the default prompts
        saveSettings()
    }
    
    // Function to update login item status
    private func updateAutoLaunchStatus() {
        if #available(macOS 13.0, *) {
            let _ = Bundle.main.bundleIdentifier ?? ""
            
            do {
                let service = SMAppService.mainApp
                
                if autoLaunchOnStartup {
                    if service.status != .enabled {
                        try service.register()
                        Logger.shared.log("Auto-launch enabled for the application")
                    }
                } else {
                    if service.status == .enabled {
                        try service.unregister()
                        Logger.shared.log("Auto-launch disabled for the application")
                    }
                }
            } catch {
                Logger.shared.log("Failed to update login item status: \(error)")
            }
        } else {
            // This feature requires macOS 13+
            Logger.shared.log("Auto-launch functionality requires macOS 13+")
        }
    }
} 