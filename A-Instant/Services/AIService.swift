import Foundation
import Combine

enum AIServiceError: Error {
    case invalidURL
    case invalidAPIKey
    case networkError(Error)
    case decodingError(Error)
    case apiError(String)
    case unknownError
}

class AIService {
    func sendPrompt(
        text: String,
        provider: AIProvider,
        model: String,
        apiKey: String
    ) -> AnyPublisher<String, AIServiceError> {
        switch provider {
        case .openAI:
            return sendOpenAIPrompt(text: text, model: model, apiKey: apiKey)
        case .anthropic:
            return sendAnthropicPrompt(text: text, model: model, apiKey: apiKey)
        case .google:
            return sendGooglePrompt(text: text, model: model, apiKey: apiKey)
        case .groq:
            return sendGroqPrompt(text: text, model: model, apiKey: apiKey)
        case .deepSeek:
            return sendDeepSeekPrompt(text: text, model: model, apiKey: apiKey)
        case .mistral:
            return sendMistralPrompt(text: text, model: model, apiKey: apiKey)
        case .ollama:
            let endpoint = UserDefaults.standard.string(forKey: UserDefaultsKeys.ollamaEndpoint) ?? "http://localhost:11434"
            return sendOllamaPrompt(text: text, model: model, endpoint: endpoint)
        }
    }
    
    // Method to fetch available models for a provider
    func fetchModels(
        provider: AIProvider,
        apiKey: String
    ) -> AnyPublisher<[String], AIServiceError> {
        switch provider {
        case .openAI:
            return fetchOpenAIModels(apiKey: apiKey)
        case .anthropic:
            return fetchAnthropicModels(apiKey: apiKey)
        case .google:
            return fetchGoogleModels(apiKey: apiKey)
        case .groq:
            return fetchGroqModels(apiKey: apiKey)
        case .deepSeek:
            return fetchDeepSeekModels(apiKey: apiKey)
        case .mistral:
            return fetchMistralModels(apiKey: apiKey)
        case .ollama:
            let endpoint = UserDefaults.standard.string(forKey: UserDefaultsKeys.ollamaEndpoint) ?? "http://localhost:11434"
            return fetchOllamaModels(endpoint: endpoint)
        }
    }
    
    // MARK: - OpenAI
    
    private func sendOpenAIPrompt(text: String, model: String, apiKey: String) -> AnyPublisher<String, AIServiceError> {
        guard !apiKey.isEmpty else {
            return Fail(error: AIServiceError.invalidAPIKey).eraseToAnyPublisher()
        }
        
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            return Fail(error: AIServiceError.invalidURL).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let requestBody: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "user", "content": text]
            ],
            "temperature": 0.7
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            return Fail(error: AIServiceError.networkError(error)).eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .mapError { AIServiceError.networkError($0) }
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw AIServiceError.unknownError
                }
                
                if httpResponse.statusCode != 200 {
                    if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let errorMessage = (errorJson["error"] as? [String: Any])?["message"] as? String {
                        throw AIServiceError.apiError(errorMessage)
                    }
                    throw AIServiceError.apiError("Status code: \(httpResponse.statusCode)")
                }
                
                return data
            }
            .decode(type: OpenAIResponse.self, decoder: JSONDecoder())
            .mapError { error in
                if let aiError = error as? AIServiceError {
                    return aiError
                }
                return AIServiceError.decodingError(error)
            }
            .map { response in
                response.choices.first?.message.content ?? "No response from the model."
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Model Endpoints
    
    private func fetchOpenAIModels(apiKey: String) -> AnyPublisher<[String], AIServiceError> {
        guard !apiKey.isEmpty else {
            return Fail(error: AIServiceError.invalidAPIKey).eraseToAnyPublisher()
        }
        
        guard let url = URL(string: "https://api.openai.com/v1/models") else {
            return Fail(error: AIServiceError.invalidURL).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .mapError { AIServiceError.networkError($0) }
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw AIServiceError.unknownError
                }
                
                if httpResponse.statusCode != 200 {
                    if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let errorMessage = (errorJson["error"] as? [String: Any])?["message"] as? String {
                        throw AIServiceError.apiError(errorMessage)
                    }
                    throw AIServiceError.apiError("Status code: \(httpResponse.statusCode)")
                }
                
                return data
            }
            .decode(type: OpenAIModelsResponse.self, decoder: JSONDecoder())
            .mapError { error in
                if let aiError = error as? AIServiceError {
                    return aiError
                }
                return AIServiceError.decodingError(error)
            }
            .map { response in
                // Filter for chat models only and sort
                let chatModels = response.data
                    .filter { $0.id.contains("gpt") }
                    .map { $0.id }
                    .sorted()
                
                return chatModels
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Anthropic
    
    private func sendAnthropicPrompt(text: String, model: String, apiKey: String) -> AnyPublisher<String, AIServiceError> {
        guard !apiKey.isEmpty else {
            return Fail(error: AIServiceError.invalidAPIKey).eraseToAnyPublisher()
        }
        
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            return Fail(error: AIServiceError.invalidURL).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "x-api-key")
        request.addValue("anthropic-swift/1.0", forHTTPHeaderField: "x-client-name")
        request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        
        let requestBody: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "user", "content": text]
            ]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            return Fail(error: AIServiceError.networkError(error)).eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .mapError { AIServiceError.networkError($0) }
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw AIServiceError.unknownError
                }
                
                if httpResponse.statusCode != 200 {
                    if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let errorMessage = errorJson["error"] as? [String: Any],
                       let message = errorMessage["message"] as? String {
                        throw AIServiceError.apiError(message)
                    }
                    throw AIServiceError.apiError("Status code: \(httpResponse.statusCode)")
                }
                
                return data
            }
            .decode(type: AnthropicResponse.self, decoder: JSONDecoder())
            .mapError { error in
                if let aiError = error as? AIServiceError {
                    return aiError
                }
                return AIServiceError.decodingError(error)
            }
            .map { response in
                if let content = response.content.first?.text {
                    return content
                }
                return "No response from the model."
            }
            .eraseToAnyPublisher()
    }
    
    private func fetchAnthropicModels(apiKey: String) -> AnyPublisher<[String], AIServiceError> {
        guard !apiKey.isEmpty else {
            return Fail(error: AIServiceError.invalidAPIKey).eraseToAnyPublisher()
        }
        
        guard let url = URL(string: "https://api.anthropic.com/v1/models") else {
            return Fail(error: AIServiceError.invalidURL).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "x-api-key")
        request.addValue("anthropic-swift/1.0", forHTTPHeaderField: "x-client-name")
        request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .mapError { AIServiceError.networkError($0) }
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw AIServiceError.unknownError
                }
                
                if httpResponse.statusCode != 200 {
                    if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let errorMessage = (errorJson["error"] as? [String: Any])?["message"] as? String {
                        throw AIServiceError.apiError(errorMessage)
                    }
                    throw AIServiceError.apiError("Status code: \(httpResponse.statusCode)")
                }
                
                return data
            }
            .decode(type: AnthropicModelsResponse.self, decoder: JSONDecoder())
            .mapError { error in
                if let aiError = error as? AIServiceError {
                    return aiError
                }
                return AIServiceError.decodingError(error)
            }
            .map { response in
                return response.models.map { $0.id }.sorted()
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Google
    
    private func sendGooglePrompt(text: String, model: String, apiKey: String) -> AnyPublisher<String, AIServiceError> {
        guard !apiKey.isEmpty else {
            return Fail(error: AIServiceError.invalidAPIKey).eraseToAnyPublisher()
        }
        
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1/models/\(model):generateContent?key=\(apiKey)") else {
            return Fail(error: AIServiceError.invalidURL).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "contents": [
                ["parts": [["text": text]]]
            ],
            "generationConfig": [
                "temperature": 0.7
            ]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            return Fail(error: AIServiceError.networkError(error)).eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .mapError { AIServiceError.networkError($0) }
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw AIServiceError.unknownError
                }
                
                if httpResponse.statusCode != 200 {
                    if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let error = errorJson["error"] as? [String: Any],
                       let message = error["message"] as? String {
                        throw AIServiceError.apiError(message)
                    }
                    throw AIServiceError.apiError("Status code: \(httpResponse.statusCode)")
                }
                
                return data
            }
            .decode(type: GoogleAIResponse.self, decoder: JSONDecoder())
            .mapError { error in
                if let aiError = error as? AIServiceError {
                    return aiError
                }
                return AIServiceError.decodingError(error)
            }
            .map { response in
                if let content = response.candidates.first?.content.parts.first?.text {
                    return content
                }
                return "No response from the model."
            }
            .eraseToAnyPublisher()
    }
    
    private func fetchGoogleModels(apiKey: String) -> AnyPublisher<[String], AIServiceError> {
        guard !apiKey.isEmpty else {
            return Fail(error: AIServiceError.invalidAPIKey).eraseToAnyPublisher()
        }
        
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1/models?key=\(apiKey)") else {
            return Fail(error: AIServiceError.invalidURL).eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: url)
            .mapError { AIServiceError.networkError($0) }
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw AIServiceError.unknownError
                }
                
                if httpResponse.statusCode != 200 {
                    if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let error = errorJson["error"] as? [String: Any],
                       let message = error["message"] as? String {
                        throw AIServiceError.apiError(message)
                    }
                    throw AIServiceError.apiError("Status code: \(httpResponse.statusCode)")
                }
                
                return data
            }
            .decode(type: GoogleModelsResponse.self, decoder: JSONDecoder())
            .mapError { error in
                if let aiError = error as? AIServiceError {
                    return aiError
                }
                return AIServiceError.decodingError(error)
            }
            .map { response in
                // Return all models
                return response.models
                    .map { $0.name.components(separatedBy: "/").last ?? $0.name }
                    .sorted()
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Groq
    
    private func sendGroqPrompt(text: String, model: String, apiKey: String) -> AnyPublisher<String, AIServiceError> {
        guard !apiKey.isEmpty else {
            return Fail(error: AIServiceError.invalidAPIKey).eraseToAnyPublisher()
        }
        
        guard let url = URL(string: "https://api.groq.com/v1/chat/completions") else {
            return Fail(error: AIServiceError.invalidURL).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let requestBody: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "user", "content": text]
            ],
            "temperature": 0.7
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            return Fail(error: AIServiceError.networkError(error)).eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .mapError { AIServiceError.networkError($0) }
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw AIServiceError.unknownError
                }
                
                if httpResponse.statusCode != 200 {
                    if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let errorMessage = (errorJson["error"] as? [String: Any])?["message"] as? String {
                        throw AIServiceError.apiError(errorMessage)
                    }
                    throw AIServiceError.apiError("Status code: \(httpResponse.statusCode)")
                }
                
                return data
            }
            .decode(type: OpenAIResponse.self, decoder: JSONDecoder())
            .mapError { error in
                if let aiError = error as? AIServiceError {
                    return aiError
                }
                return AIServiceError.decodingError(error)
            }
            .map { response in
                response.choices.first?.message.content ?? "No response from the model."
            }
            .eraseToAnyPublisher()
    }
    
    private func fetchGroqModels(apiKey: String) -> AnyPublisher<[String], AIServiceError> {
        guard !apiKey.isEmpty else {
            return Fail(error: AIServiceError.invalidAPIKey).eraseToAnyPublisher()
        }
        
        guard let url = URL(string: "https://api.groq.com/openai/v1/models") else {
            return Fail(error: AIServiceError.invalidURL).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .mapError { AIServiceError.networkError($0) }
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw AIServiceError.unknownError
                }
                
                if httpResponse.statusCode != 200 {
                    if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        if let errorObj = errorJson["error"] as? [String: Any],
                           let message = errorObj["message"] as? String {
                            throw AIServiceError.apiError(message)
                        } else if let message = errorJson["message"] as? String {
                            throw AIServiceError.apiError(message)
                        } else if let error = errorJson["error"] as? String {
                            throw AIServiceError.apiError(error)
                        }
                    }
                    throw AIServiceError.apiError("Status code: \(httpResponse.statusCode)")
                }
                
                return data
            }
            .decode(type: GroqModelsResponse.self, decoder: JSONDecoder())
            .mapError { error in
                if let aiError = error as? AIServiceError {
                    return aiError
                }
                return AIServiceError.decodingError(error)
            }
            .map { response in
                return response.data.map { $0.id }.sorted()
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - DeepSeek
    
    private func sendDeepSeekPrompt(text: String, model: String, apiKey: String) -> AnyPublisher<String, AIServiceError> {
        guard !apiKey.isEmpty else {
            return Fail(error: AIServiceError.invalidAPIKey).eraseToAnyPublisher()
        }
        
        guard let url = URL(string: "https://api.deepseek.com/v1/chat/completions") else {
            return Fail(error: AIServiceError.invalidURL).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let requestBody: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "user", "content": text]
            ],
            "temperature": 0.7
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            return Fail(error: AIServiceError.networkError(error)).eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .mapError { AIServiceError.networkError($0) }
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw AIServiceError.unknownError
                }
                
                if httpResponse.statusCode != 200 {
                    if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let errorMessage = (errorJson["error"] as? [String: Any])?["message"] as? String {
                        throw AIServiceError.apiError(errorMessage)
                    }
                    throw AIServiceError.apiError("Status code: \(httpResponse.statusCode)")
                }
                
                return data
            }
            .decode(type: OpenAIResponse.self, decoder: JSONDecoder())
            .mapError { error in
                if let aiError = error as? AIServiceError {
                    return aiError
                }
                return AIServiceError.decodingError(error)
            }
            .map { response in
                response.choices.first?.message.content ?? "No response from the model."
            }
            .eraseToAnyPublisher()
    }
    
    private func fetchDeepSeekModels(apiKey: String) -> AnyPublisher<[String], AIServiceError> {
        guard !apiKey.isEmpty else {
            return Fail(error: AIServiceError.invalidAPIKey).eraseToAnyPublisher()
        }
        
        guard let url = URL(string: "https://api.deepseek.com/v1/models") else {
            return Fail(error: AIServiceError.invalidURL).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .mapError { AIServiceError.networkError($0) }
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw AIServiceError.unknownError
                }
                
                if httpResponse.statusCode != 200 {
                    if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let errorMessage = (errorJson["error"] as? [String: Any])?["message"] as? String {
                        throw AIServiceError.apiError(errorMessage)
                    }
                    throw AIServiceError.apiError("Status code: \(httpResponse.statusCode)")
                }
                
                return data
            }
            .decode(type: DeepSeekModelsResponse.self, decoder: JSONDecoder())
            .mapError { error in
                if let aiError = error as? AIServiceError {
                    return aiError
                }
                return AIServiceError.decodingError(error)
            }
            .map { response in
                return response.data.map { $0.id }.sorted()
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Ollama
    
    private func sendOllamaPrompt(text: String, model: String, endpoint: String) -> AnyPublisher<String, AIServiceError> {
        guard let url = URL(string: "\(endpoint)/api/generate") else {
            return Fail(error: AIServiceError.invalidURL).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "model": model,
            "prompt": text,
            "stream": false
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            return Fail(error: AIServiceError.networkError(error)).eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .mapError { AIServiceError.networkError($0) }
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw AIServiceError.unknownError
                }
                
                if httpResponse.statusCode != 200 {
                    if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let errorMessage = errorJson["error"] as? String {
                        throw AIServiceError.apiError(errorMessage)
                    }
                    throw AIServiceError.apiError("Status code: \(httpResponse.statusCode)")
                }
                
                return data
            }
            .decode(type: OllamaResponse.self, decoder: JSONDecoder())
            .mapError { error in
                if let aiError = error as? AIServiceError {
                    return aiError
                }
                return AIServiceError.decodingError(error)
            }
            .map { $0.response }
            .eraseToAnyPublisher()
    }
    
    private func fetchOllamaModels(endpoint: String) -> AnyPublisher<[String], AIServiceError> {
        guard let url = URL(string: "\(endpoint)/api/tags") else {
            return Fail(error: AIServiceError.invalidURL).eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: url)
            .mapError { AIServiceError.networkError($0) }
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw AIServiceError.unknownError
                }
                
                if httpResponse.statusCode != 200 {
                    if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let errorMessage = errorJson["error"] as? String {
                        throw AIServiceError.apiError(errorMessage)
                    }
                    throw AIServiceError.apiError("Status code: \(httpResponse.statusCode)")
                }
                
                return data
            }
            .decode(type: OllamaModelsResponse.self, decoder: JSONDecoder())
            .mapError { error in
                if let aiError = error as? AIServiceError {
                    return aiError
                }
                return AIServiceError.decodingError(error)
            }
            .map { response in
                return response.models.map { $0.name }.sorted()
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Mistral
    
    private func sendMistralPrompt(text: String, model: String, apiKey: String) -> AnyPublisher<String, AIServiceError> {
        guard !apiKey.isEmpty else {
            return Fail(error: AIServiceError.invalidAPIKey).eraseToAnyPublisher()
        }
        
        guard let url = URL(string: "https://api.mistral.ai/v1/chat/completions") else {
            return Fail(error: AIServiceError.invalidURL).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let requestBody: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "user", "content": text]
            ],
            "temperature": 0.7
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            return Fail(error: AIServiceError.networkError(error)).eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .mapError { AIServiceError.networkError($0) }
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw AIServiceError.unknownError
                }
                
                if httpResponse.statusCode != 200 {
                    if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let errorMessage = (errorJson["error"] as? [String: Any])?["message"] as? String {
                        throw AIServiceError.apiError(errorMessage)
                    }
                    throw AIServiceError.apiError("Status code: \(httpResponse.statusCode)")
                }
                
                return data
            }
            .decode(type: MistralResponse.self, decoder: JSONDecoder())
            .mapError { error in
                if let aiError = error as? AIServiceError {
                    return aiError
                }
                return AIServiceError.decodingError(error)
            }
            .map { response in
                response.choices.first?.message.content ?? "No response from the model."
            }
            .eraseToAnyPublisher()
    }
    
    private func fetchMistralModels(apiKey: String) -> AnyPublisher<[String], AIServiceError> {
        guard !apiKey.isEmpty else {
            return Fail(error: AIServiceError.invalidAPIKey).eraseToAnyPublisher()
        }
        
        guard let url = URL(string: "https://api.mistral.ai/v1/models") else {
            return Fail(error: AIServiceError.invalidURL).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .mapError { AIServiceError.networkError($0) }
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw AIServiceError.unknownError
                }
                
                if httpResponse.statusCode != 200 {
                    if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let errorMessage = (errorJson["error"] as? [String: Any])?["message"] as? String {
                        throw AIServiceError.apiError(errorMessage)
                    }
                    throw AIServiceError.apiError("Status code: \(httpResponse.statusCode)")
                }
                
                return data
            }
            .decode(type: MistralModelsResponse.self, decoder: JSONDecoder())
            .mapError { error in
                if let aiError = error as? AIServiceError {
                    return aiError
                }
                return AIServiceError.decodingError(error)
            }
            .map { response in
                // Filter for chat models and sort
                return response.data
                    .filter { $0.capabilities.completion_chat }
                    .map { $0.id }
                    .sorted()
            }
            .eraseToAnyPublisher()
    }
}

// MARK: - Response Models

struct OpenAIResponse: Decodable {
    struct Message: Decodable {
        let content: String
    }
    
    struct Choice: Decodable {
        let message: Message
    }
    
    let choices: [Choice]
}

struct AnthropicResponse: Decodable {
    struct ContentBlock: Decodable {
        let type: String
        let text: String
    }
    
    let content: [ContentBlock]
}

struct OllamaResponse: Decodable {
    let response: String
}

struct GoogleAIResponse: Decodable {
    struct Content: Decodable {
        struct Part: Decodable {
            let text: String
        }
        
        let parts: [Part]
    }
    
    struct Candidate: Decodable {
        let content: Content
    }
    
    let candidates: [Candidate]
}

// MARK: - Model Response Types

struct OpenAIModelsResponse: Decodable {
    let data: [OpenAIModel]
}

struct OpenAIModel: Decodable {
    let id: String
}

struct AnthropicModelsResponse: Decodable {
    struct Model: Decodable {
        let id: String
    }
    
    let models: [Model]
}

struct GoogleModelsResponse: Decodable {
    struct Model: Decodable {
        let name: String
    }
    
    let models: [Model]
}

struct GroqModelsResponse: Decodable {
    struct Model: Decodable {
        let id: String
        let object: String
        let created: Int
        let owned_by: String?
    }
    
    let object: String
    let data: [Model]
}

struct DeepSeekModelsResponse: Decodable {
    struct Model: Decodable {
        let id: String
    }
    
    let data: [Model]
}

struct OllamaModelsResponse: Decodable {
    struct Model: Decodable {
        let name: String
    }
    
    let models: [Model]
}

struct MistralResponse: Decodable {
    struct Message: Decodable {
        let content: String
    }
    
    struct Choice: Decodable {
        let message: Message
    }
    
    let choices: [Choice]
}

struct MistralModelsResponse: Decodable {
    struct Model: Decodable {
        let id: String
        let capabilities: Capabilities
    }
    
    let data: [Model]
}

struct Capabilities: Decodable {
    let completion_chat: Bool
} 