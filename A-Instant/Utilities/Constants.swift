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