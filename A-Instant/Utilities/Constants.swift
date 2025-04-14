import Foundation

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
}

enum AIProvider: String, CaseIterable, Identifiable {
    case openAI = "OpenAI"
    case anthropic = "Anthropic"
    case google = "Google"
    case groq = "Groq"
    case deepSeek = "DeepSeek"
    case ollama = "Ollama"
    
    var id: String { self.rawValue }
    
    var apiKeyUserDefaultsKey: String {
        switch self {
        case .openAI: return UserDefaultsKeys.openAIKey
        case .anthropic: return UserDefaultsKeys.anthropicKey
        case .google: return UserDefaultsKeys.googleKey
        case .groq: return UserDefaultsKeys.groqKey
        case .deepSeek: return UserDefaultsKeys.deepSeekKey
        case .ollama: return UserDefaultsKeys.ollamaEndpoint
        }
    }
    
    var modelUserDefaultsKey: String {
        switch self {
        case .openAI: return UserDefaultsKeys.openAIModel
        case .anthropic: return UserDefaultsKeys.anthropicModel
        case .google: return UserDefaultsKeys.googleModel
        case .groq: return UserDefaultsKeys.groqModel
        case .deepSeek: return UserDefaultsKeys.deepSeekModel
        case .ollama: return UserDefaultsKeys.ollamaModel
        }
    }
}

struct SavedPrompt: Identifiable, Codable {
    var id = UUID()
    var name: String
    var promptText: String
}

struct Shortcut: Identifiable, Codable {
    var id = UUID()
    var name: String
    var promptId: UUID
    var keyBinding: String
} 