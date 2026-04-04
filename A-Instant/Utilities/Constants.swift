import Foundation
import SwiftUI

struct UserDefaultsKeys {
    static let triggerKey = "triggerKey"
    static let aiProvider = "aiProvider"
    static let openAIKey = "openAIKey"
    static let anthropicKey = "anthropicKey"
    static let googleKey = "googleKey"
    static let groqKey = "groqKey"
    static let deepSeekKey = "deepSeekKey"
    static let ollamaEndpoint = "ollamaEndpoint"
    static let openAIModel = "openAIModel"
    static let anthropicModel = "anthropicModel"
    static let googleModel = "googleModel"
    static let groqModel = "groqModel"
    static let deepSeekModel = "deepSeekModel"
    static let ollamaModel = "ollamaModel"
    static let savedPrompts = "savedPrompts"
    static let shortcuts = "shortcuts"
    static let autoLaunchOnStartup = "autoLaunchOnStartup"
    static let mistralKey = "mistralKey"
    static let mistralModel = "mistralModel"
    static let xAIKey = "xAIKey"
    static let xAIModel = "xAIModel"
    static let genericOpenAIKey = "genericOpenAIKey"
    static let genericOpenAIModel = "genericOpenAIModel"
    static let genericOpenAIEndpoint = "genericOpenAIEndpoint"
    static let enableAutomaticUpdates = "enableAutomaticUpdates"
    static let enableDebugLogging = "enableDebugLogging"
    static let nonDestructiveMode = "nonDestructiveMode"
    static let lmStudioKey = "lmStudioKey"
    static let lmStudioModel = "lmStudioModel"
    static let lmStudioEndpoint = "lmStudioEndpoint"
    static let opencodeZenKey = "opencodeZenKey"
    static let opencodeZenModel = "opencodeZenModel"
    static let opencodeZenEndpoint = "opencodeZenEndpoint"
    static let openRouterKey = "openRouterKey"
    static let openRouterModel = "openRouterModel"
    static let openRouterEndpoint = "openRouterEndpoint"
    static let ollamaCloudKey = "ollamaCloudKey"
    static let ollamaCloudModel = "ollamaCloudModel"
    
    // Cached model lists
    static let cachedOpenAIModels = "cachedOpenAIModels"
    static let cachedAnthropicModels = "cachedAnthropicModels"
    static let cachedGoogleModels = "cachedGoogleModels"
    static let cachedGroqModels = "cachedGroqModels"
    static let cachedDeepSeekModels = "cachedDeepSeekModels"
    static let cachedMistralModels = "cachedMistralModels"
    static let cachedOllamaModels = "cachedOllamaModels"
    static let cachedXAIModels = "cachedXAIModels"
    static let cachedGenericOpenAIModels = "cachedGenericOpenAIModels"
    static let cachedLMStudioModels = "cachedLMStudioModels"
    static let cachedOpencodeZenModels = "cachedOpencodeZenModels"
    static let cachedOpenRouterModels = "cachedOpenRouterModels"
    static let cachedOllamaCloudModels = "cachedOllamaCloudModels"
    static let opencodeZenOnlyFreeModels = "opencodeZenOnlyFreeModels"
    static let openRouterOnlyFreeModels = "openRouterOnlyFreeModels"
}

enum AIProvider: String, CaseIterable, Identifiable {
    case openAI = "OpenAI"
    case anthropic = "Anthropic"
    case google = "Google"
    case groq = "Groq"
    case deepSeek = "DeepSeek"
    case mistral = "Mistral"
    case ollama = "Ollama"
    case xAI = "xAI"
    case genericOpenAI = "Custom"
    case lmStudio = "LM Studio"
    case opencodeZen = "Opencode Zen"
    case openRouter = "OpenRouter"
    case ollamaCloud = "Ollama Cloud"
    
    var id: String { self.rawValue }
    
    var apiKeyUserDefaultsKey: String {
        switch self {
        case .openAI: return UserDefaultsKeys.openAIKey
        case .anthropic: return UserDefaultsKeys.anthropicKey
        case .google: return UserDefaultsKeys.googleKey
        case .groq: return UserDefaultsKeys.groqKey
        case .deepSeek: return UserDefaultsKeys.deepSeekKey
        case .mistral: return UserDefaultsKeys.mistralKey
        case .ollama: return UserDefaultsKeys.ollamaEndpoint
        case .xAI: return UserDefaultsKeys.xAIKey
        case .genericOpenAI: return UserDefaultsKeys.genericOpenAIKey
        case .lmStudio: return UserDefaultsKeys.lmStudioKey
        case .opencodeZen: return UserDefaultsKeys.opencodeZenKey
        case .openRouter: return UserDefaultsKeys.openRouterKey
        case .ollamaCloud: return UserDefaultsKeys.ollamaCloudKey
        }
    }
    
    var modelUserDefaultsKey: String {
        switch self {
        case .openAI: return UserDefaultsKeys.openAIModel
        case .anthropic: return UserDefaultsKeys.anthropicModel
        case .google: return UserDefaultsKeys.googleModel
        case .groq: return UserDefaultsKeys.groqModel
        case .deepSeek: return UserDefaultsKeys.deepSeekModel
        case .mistral: return UserDefaultsKeys.mistralModel
        case .ollama: return UserDefaultsKeys.ollamaModel
        case .xAI: return UserDefaultsKeys.xAIModel
        case .genericOpenAI: return UserDefaultsKeys.genericOpenAIModel
        case .lmStudio: return UserDefaultsKeys.lmStudioModel
        case .opencodeZen: return UserDefaultsKeys.opencodeZenModel
        case .openRouter: return UserDefaultsKeys.openRouterModel
        case .ollamaCloud: return UserDefaultsKeys.ollamaCloudModel
        }
    }
    
    var cachedModelsUserDefaultsKey: String {
        switch self {
        case .openAI: return UserDefaultsKeys.cachedOpenAIModels
        case .anthropic: return UserDefaultsKeys.cachedAnthropicModels
        case .google: return UserDefaultsKeys.cachedGoogleModels
        case .groq: return UserDefaultsKeys.cachedGroqModels
        case .deepSeek: return UserDefaultsKeys.cachedDeepSeekModels
        case .mistral: return UserDefaultsKeys.cachedMistralModels
        case .ollama: return UserDefaultsKeys.cachedOllamaModels
        case .xAI: return UserDefaultsKeys.cachedXAIModels
        case .genericOpenAI: return UserDefaultsKeys.cachedGenericOpenAIModels
        case .lmStudio: return UserDefaultsKeys.cachedLMStudioModels
        case .opencodeZen: return UserDefaultsKeys.cachedOpencodeZenModels
        case .openRouter: return UserDefaultsKeys.cachedOpenRouterModels
        case .ollamaCloud: return UserDefaultsKeys.cachedOllamaCloudModels
        }
    }
    
    var usesEndpointInsteadOfKey: Bool {
        switch self {
        case .ollama, .lmStudio: return true
        case .ollamaCloud: return false
        default: return false
        }
    }
    
    var endpointUserDefaultsKey: String? {
        switch self {
        case .ollama: return UserDefaultsKeys.ollamaEndpoint
        case .lmStudio: return UserDefaultsKeys.lmStudioEndpoint
        case .opencodeZen: return UserDefaultsKeys.opencodeZenEndpoint
        case .openRouter: return UserDefaultsKeys.openRouterEndpoint
        default: return nil
        }
    }
}

struct SavedPrompt: Identifiable, Codable, Transferable {
    var id = UUID()
    var name: String
    var promptText: String
    
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .json)
    }
}

struct Shortcut: Identifiable, Codable {
    var id = UUID()
    var name: String
    var promptId: UUID
    var keyBinding: String
} 