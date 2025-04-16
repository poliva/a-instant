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
    @Published var xAIKey: String = ""
    @Published var genericOpenAIKey: String = ""
    @Published var genericOpenAIEndpoint: String = "https://openrouter.ai/api/v1"
    @Published var autoLaunchOnStartup: Bool = true
    @Published var enableAutomaticUpdates: Bool = true
    @Published var enableDebugLogging: Bool = false
    @Published var nonDestructiveMode: Bool = false
    
    @Published var openAIModel: String = ""
    @Published var anthropicModel: String = ""
    @Published var googleModel: String = ""
    @Published var groqModel: String = ""
    @Published var deepSeekModel: String = ""
    @Published var mistralModel: String = ""
    @Published var ollamaModel: String = ""
    @Published var xAIModel: String = ""
    @Published var genericOpenAIModel: String = ""
    
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
        
        // Set up observers for settings changes
        $enableAutomaticUpdates
            .dropFirst() // Skip initial value
            .sink { [weak self] newValue in
                self?.updateAutomaticUpdatesStatus(newValue)
            }
            .store(in: &cancellables)
            
        // Set up observer for provider changes to load the appropriate cached models
        $selectedProvider
            .dropFirst() // Skip initial value
            .sink { [weak self] newProvider in
                self?.loadCachedModels()
            }
            .store(in: &cancellables)
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
        xAIKey = UserDefaults.standard.string(forKey: UserDefaultsKeys.xAIKey) ?? ""
        genericOpenAIKey = UserDefaults.standard.string(forKey: UserDefaultsKeys.genericOpenAIKey) ?? ""
        genericOpenAIEndpoint = UserDefaults.standard.string(forKey: UserDefaultsKeys.genericOpenAIEndpoint) ?? "https://openrouter.ai/api/v1"
        
        // Load model selections
        openAIModel = UserDefaults.standard.string(forKey: UserDefaultsKeys.openAIModel) ?? ""
        anthropicModel = UserDefaults.standard.string(forKey: UserDefaultsKeys.anthropicModel) ?? ""
        googleModel = UserDefaults.standard.string(forKey: UserDefaultsKeys.googleModel) ?? ""
        groqModel = UserDefaults.standard.string(forKey: UserDefaultsKeys.groqModel) ?? ""
        deepSeekModel = UserDefaults.standard.string(forKey: UserDefaultsKeys.deepSeekModel) ?? ""
        mistralModel = UserDefaults.standard.string(forKey: UserDefaultsKeys.mistralModel) ?? ""
        ollamaModel = UserDefaults.standard.string(forKey: UserDefaultsKeys.ollamaModel) ?? ""
        xAIModel = UserDefaults.standard.string(forKey: UserDefaultsKeys.xAIModel) ?? ""
        genericOpenAIModel = UserDefaults.standard.string(forKey: UserDefaultsKeys.genericOpenAIModel) ?? ""
        
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
        
        // Load automatic updates setting, defaulting to true if not set
        enableAutomaticUpdates = UserDefaults.standard.object(forKey: UserDefaultsKeys.enableAutomaticUpdates) as? Bool ?? true
        
        // Load debug logging setting, defaulting to false if not set
        enableDebugLogging = UserDefaults.standard.object(forKey: UserDefaultsKeys.enableDebugLogging) as? Bool ?? false
        
        // Load non-destructive mode setting, defaulting to false if not set
        nonDestructiveMode = UserDefaults.standard.object(forKey: UserDefaultsKeys.nonDestructiveMode) as? Bool ?? false
        
        // Apply auto-launch setting
        updateAutoLaunchStatus()
        
        // Load cached models for the current provider
        loadCachedModels()
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
        UserDefaults.standard.set(xAIKey, forKey: UserDefaultsKeys.xAIKey)
        UserDefaults.standard.set(genericOpenAIKey, forKey: UserDefaultsKeys.genericOpenAIKey)
        UserDefaults.standard.set(genericOpenAIEndpoint, forKey: UserDefaultsKeys.genericOpenAIEndpoint)
        
        // Save model selections
        UserDefaults.standard.set(openAIModel, forKey: UserDefaultsKeys.openAIModel)
        UserDefaults.standard.set(anthropicModel, forKey: UserDefaultsKeys.anthropicModel)
        UserDefaults.standard.set(googleModel, forKey: UserDefaultsKeys.googleModel)
        UserDefaults.standard.set(groqModel, forKey: UserDefaultsKeys.groqModel)
        UserDefaults.standard.set(deepSeekModel, forKey: UserDefaultsKeys.deepSeekModel)
        UserDefaults.standard.set(mistralModel, forKey: UserDefaultsKeys.mistralModel)
        UserDefaults.standard.set(ollamaModel, forKey: UserDefaultsKeys.ollamaModel)
        UserDefaults.standard.set(xAIModel, forKey: UserDefaultsKeys.xAIModel)
        UserDefaults.standard.set(genericOpenAIModel, forKey: UserDefaultsKeys.genericOpenAIModel)
        
        // Save prompts
        do {
            let data = try JSONEncoder().encode(savedPrompts)
            UserDefaults.standard.set(data, forKey: UserDefaultsKeys.savedPrompts)
        } catch {
            Logger.shared.log("Error saving prompts: \(error)")
        }
        
        // Save auto-launch setting
        UserDefaults.standard.set(autoLaunchOnStartup, forKey: UserDefaultsKeys.autoLaunchOnStartup)
        
        // Save automatic updates setting
        UserDefaults.standard.set(enableAutomaticUpdates, forKey: UserDefaultsKeys.enableAutomaticUpdates)
        
        // Save debug logging setting
        UserDefaults.standard.set(enableDebugLogging, forKey: UserDefaultsKeys.enableDebugLogging)
        
        // Save non-destructive mode setting
        UserDefaults.standard.set(nonDestructiveMode, forKey: UserDefaultsKeys.nonDestructiveMode)
        
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
        case .xAI:
            apiKey = xAIKey
            if apiKey.isEmpty {
                modelLoadError = "Please enter your xAI API key in the API tab"
                isLoadingModels = false
                return
            }
        case .genericOpenAI:
            apiKey = genericOpenAIKey
            if apiKey.isEmpty {
                modelLoadError = "Please enter your Generic OpenAI API key in the API tab"
                isLoadingModels = false
                return
            }
        }
        
        aiService.fetchModels(provider: selectedProvider, apiKey: apiKey)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoadingModels = false
                    
                    if case .failure(let error) = completion {
                        // Extract a user-friendly error message
                        self?.modelLoadError = error.userFriendlyMessage
                        self?.availableModels = []
                    }
                },
                receiveValue: { [weak self] models in
                    guard let self = self else { return }
                    self.availableModels = models
                    
                    // Save models to UserDefaults for caching
                    self.saveModelsToCache(models)
                    
                    // If current model is empty and we have models, set the first one
                    if self.currentModel.isEmpty && !models.isEmpty {
                        self.setCurrentModel(models[0])
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    private func saveModelsToCache(_ models: [String]) {
        let cacheKey = selectedProvider.cachedModelsUserDefaultsKey
        do {
            let data = try JSONEncoder().encode(models)
            UserDefaults.standard.set(data, forKey: cacheKey)
        } catch {
            Logger.shared.log("Error caching models: \(error)")
        }
    }
    
    func loadCachedModels() {
        let cacheKey = selectedProvider.cachedModelsUserDefaultsKey
        if let data = UserDefaults.standard.data(forKey: cacheKey) {
            do {
                let models = try JSONDecoder().decode([String].self, from: data)
                availableModels = models
                Logger.shared.log("Loaded \(models.count) cached models for \(selectedProvider.rawValue)")
            } catch {
                Logger.shared.log("Error loading cached models: \(error)")
                availableModels = []
            }
        } else {
            availableModels = []
        }
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
        case .xAI: return xAIKey
        case .genericOpenAI: return genericOpenAIKey
        }
    }
    
    var currentModel: String {
        switch selectedProvider {
        case .openAI:
            return openAIModel
        case .anthropic:
            return anthropicModel
        case .google:
            return googleModel
        case .groq:
            return groqModel
        case .deepSeek:
            return deepSeekModel
        case .mistral:
            return mistralModel
        case .ollama:
            return ollamaModel
        case .xAI:
            return xAIModel
        case .genericOpenAI:
            return genericOpenAIModel
        }
    }
    
    // Make sure availableModels contains at least the current model
    var displayModels: [String] {
        if availableModels.isEmpty && !currentModel.isEmpty {
            return [currentModel]
        }
        
        // If the current model is not in the available models list, add it
        if !currentModel.isEmpty && !availableModels.contains(currentModel) {
            var models = availableModels
            models.append(currentModel)
            return models.sorted()
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
        case .xAI:
            xAIModel = model
            UserDefaults.standard.set(model, forKey: UserDefaultsKeys.xAIModel)
        case .genericOpenAI:
            genericOpenAIModel = model
            UserDefaults.standard.set(model, forKey: UserDefaultsKeys.genericOpenAIModel)
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
    
    // Method to update automatic updates behavior when setting changes
    private func updateAutomaticUpdatesStatus(_ isEnabled: Bool) {
        NotificationCenter.default.post(
            name: Notification.Name("UpdateAutomaticUpdatesSettingChanged"),
            object: nil,
            userInfo: ["isEnabled": isEnabled]
        )
    }
} 