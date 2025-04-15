import Foundation
import Combine

enum AIServiceError: Error {
    case invalidURL
    case invalidAPIKey
    case networkError(Error)
    case decodingError(Error)
    case apiError(String)
    case unknownError
    case invalidRequestData(Error)
    case invalidResponse
    case requestFailed(Int, String)
    case unknown(Error)
    
    var userFriendlyMessage: String {
        switch self {
        case .invalidURL:
            return "Invalid URL configuration"
        case .invalidAPIKey:
            return "Invalid API key"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .apiError(let message):
            return message
        case .unknownError:
            return "An unknown error occurred"
        case .invalidRequestData(let error):
            return "Invalid request data: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server"
        case .requestFailed(let code, let message):
            if let data = message.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                
                if let type = json["type"] as? String, type == "error",
                   let error = json["error"] as? [String: Any],
                   let errorType = error["type"] as? String,
                   let errorMsg = error["message"] as? String {
                    return "Error (\(errorType)): \(errorMsg)"
                }
                
                if let error = json["error"] as? [String: Any],
                   let errorMsg = error["message"] as? String {
                    return "Error: \(errorMsg)"
                }
                
                if let errorMsg = json["message"] as? String {
                    return "Error: \(errorMsg)"
                }
            }
            return "Request failed (HTTP \(code)): \(message)"
        case .unknown(let error):
            return "Error: \(error.localizedDescription)"
        }
    }
}

class AIService {
    // MARK: - Private helpers for logging
    
    private func logRequest(_ request: URLRequest, provider: String, endpoint: String) {
        var logMessage = "API Request to \(provider) - \(endpoint)\n"
        
        // Mask API key in URL if present
        if let urlString = request.url?.absoluteString {
            // Create a censored version of the URL that hides API keys
            var censoredURL = urlString
            // Handle key= parameter in URL (used by Google API)
            censoredURL = censoredURL.replacingOccurrences(of: #"key=[^&]*"#, with: "key=[REDACTED]", options: .regularExpression)
            logMessage += "URL: \(censoredURL)\n"
        } else {
            logMessage += "URL: unknown\n"
        }
        
        if let method = request.httpMethod {
            logMessage += "Method: \(method)\n"
        }
        
        logMessage += "Headers: \n"
        if let headers = request.allHTTPHeaderFields {
            for (key, value) in headers {
                // Mask API keys in the log
                if key.lowercased().contains("api") || key.lowercased().contains("key") || key.lowercased().contains("authorization") {
                    logMessage += "  \(key): [REDACTED]\n"
                } else {
                    logMessage += "  \(key): \(value)\n"
                }
            }
        }
        
        if let body = request.httpBody, let bodyString = String(data: body, encoding: .utf8) {
            // Create a censored version of the body that hides API keys and sensitive data
            var censoredBody = bodyString
            // Basic JSON censoring - should be improved for production code
            censoredBody = censoredBody.replacingOccurrences(of: #"("api_key"|"key"|"Authorization"|"auth"|"token"|"password"):"[^"]*"#, with: "$1:\"[REDACTED]\"", options: .regularExpression)
            
            logMessage += "Body: \(censoredBody)"
        }
        
        Logger.shared.log(logMessage)
    }
    
    private func logResponse(data: Data, response: URLResponse, provider: String, endpoint: String) {
        guard let httpResponse = response as? HTTPURLResponse else {
            Logger.shared.log("Invalid response type from \(provider) - \(endpoint)")
            return
        }
        
        var logMessage = "API Response from \(provider) - \(endpoint)\n"
        logMessage += "Status Code: \(httpResponse.statusCode)\n"
        
        // Log headers
        logMessage += "Headers: \n"
        for (key, value) in httpResponse.allHeaderFields {
            logMessage += "  \(key): \(value)\n"
        }
        
        // Log response body (truncated if large)
        if let responseString = String(data: data, encoding: .utf8) {
            let truncatedResponse = responseString.count > 1000 ? responseString.prefix(1000) + "... [truncated]" : responseString
            logMessage += "Body: \(truncatedResponse)"
        } else {
            logMessage += "Body: [Binary data of \(data.count) bytes]"
        }
        
        Logger.shared.log(logMessage)
    }
    
    private func logError(_ error: Error, provider: String, endpoint: String) {
        Logger.shared.log("API Error from \(provider) - \(endpoint): \(error.localizedDescription)")
    }
    
    // MARK: - Public Methods
    
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
    
    func sendPrompt(
        text: String,
        systemPrompt: String? = nil,
        provider: AIProvider,
        model: String,
        apiKey: String
    ) -> AnyPublisher<String, AIServiceError> {
        switch provider {
        case .openAI:
            return sendOpenAIPrompt(text: text, systemPrompt: systemPrompt, model: model, apiKey: apiKey)
        case .anthropic:
            return sendAnthropicPrompt(text: text, systemPrompt: systemPrompt, model: model, apiKey: apiKey)
        case .google:
            return sendGooglePrompt(text: text, systemPrompt: systemPrompt, model: model, apiKey: apiKey)
        case .groq:
            return sendGroqPrompt(text: text, systemPrompt: systemPrompt, model: model, apiKey: apiKey)
        case .deepSeek:
            return sendDeepSeekPrompt(text: text, systemPrompt: systemPrompt, model: model, apiKey: apiKey)
        case .mistral:
            return sendMistralPrompt(text: text, systemPrompt: systemPrompt, model: model, apiKey: apiKey)
        case .ollama:
            let endpoint = UserDefaults.standard.string(forKey: UserDefaultsKeys.ollamaEndpoint) ?? "http://localhost:11434"
            return sendOllamaPrompt(text: text, systemPrompt: systemPrompt, model: model, endpoint: endpoint)
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
    
    private func sendOpenAIPrompt(
        text: String,
        systemPrompt: String? = nil,
        model: String,
        apiKey: String
    ) -> AnyPublisher<String, AIServiceError> {
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
        
        var messages: [[String: Any]] = []
        
        if let systemPrompt = systemPrompt, !systemPrompt.isEmpty {
            messages.append(["role": "system", "content": systemPrompt])
        }
        
        messages.append(["role": "user", "content": text])
        
        let requestBody: [String: Any] = [
            "model": model,
            "messages": messages,
            "temperature": 0.7
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            // Log the request
            logRequest(request, provider: "OpenAI", endpoint: "chat/completions")
        } catch {
            logError(error, provider: "OpenAI", endpoint: "chat/completions")
            return Fail(error: AIServiceError.invalidRequestData(error)).eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response in
                // Log the response
                self.logResponse(data: data, response: response, provider: "OpenAI", endpoint: "chat/completions")
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw AIServiceError.invalidResponse
                }
                
                if httpResponse.statusCode != 200 {
                    if let errorString = String(data: data, encoding: .utf8) {
                        throw AIServiceError.requestFailed(httpResponse.statusCode, errorString)
                    } else {
                        throw AIServiceError.requestFailed(httpResponse.statusCode, "Unknown error")
                    }
                }
                
                return data
            }
            .decode(type: OpenAIResponse.self, decoder: JSONDecoder())
            .map { response in
                guard let choice = response.choices.first else {
                    return "No response generated"
                }
                return choice.message.content
            }
            .mapError { error in
                self.logError(error, provider: "OpenAI", endpoint: "chat/completions")
                if let aiError = error as? AIServiceError {
                    return aiError
                } else if let decodingError = error as? DecodingError {
                    return AIServiceError.decodingError(decodingError)
                } else {
                    return AIServiceError.unknown(error)
                }
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
        
        // Log the request
        logRequest(request, provider: "OpenAI", endpoint: "models")
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .mapError { AIServiceError.networkError($0) }
            .tryMap { data, response in
                // Log the response
                self.logResponse(data: data, response: response, provider: "OpenAI", endpoint: "models")
                
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
                self.logError(error, provider: "OpenAI", endpoint: "models")
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
    
    private func sendAnthropicPrompt(
        text: String,
        systemPrompt: String? = nil,
        model: String,
        apiKey: String
    ) -> AnyPublisher<String, AIServiceError> {
        guard !apiKey.isEmpty else {
            return Fail(error: AIServiceError.invalidAPIKey).eraseToAnyPublisher()
        }
        
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            return Fail(error: AIServiceError.invalidURL).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("anthropic-version: 2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "x-api-key")
        
        var requestBody: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "messages": [
                ["role": "user", "content": text]
            ]
        ]
        
        if let systemPrompt = systemPrompt, !systemPrompt.isEmpty {
            requestBody["system"] = systemPrompt
        }
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            // Log the request
            logRequest(request, provider: "Anthropic", endpoint: "messages")
        } catch {
            logError(error, provider: "Anthropic", endpoint: "messages")
            return Fail(error: AIServiceError.invalidRequestData(error)).eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response in
                // Log the response
                self.logResponse(data: data, response: response, provider: "Anthropic", endpoint: "messages")
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw AIServiceError.invalidResponse
                }
                
                if httpResponse.statusCode != 200 {
                    if let errorString = String(data: data, encoding: .utf8) {
                        throw AIServiceError.requestFailed(httpResponse.statusCode, errorString)
                    } else {
                        throw AIServiceError.requestFailed(httpResponse.statusCode, "Unknown error")
                    }
                }
                
                return data
            }
            .decode(type: AnthropicResponse.self, decoder: JSONDecoder())
            .map { response in
                let textBlocks = response.content.filter { $0.type == "text" }
                guard let firstTextBlock = textBlocks.first else {
                    return "No response generated"
                }
                return firstTextBlock.text
            }
            .mapError { error in
                self.logError(error, provider: "Anthropic", endpoint: "messages")
                if let aiError = error as? AIServiceError {
                    return aiError
                } else if let decodingError = error as? DecodingError {
                    return AIServiceError.decodingError(decodingError)
                } else {
                    return AIServiceError.unknown(error)
                }
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
        
        // Log the request
        logRequest(request, provider: "Anthropic", endpoint: "models")
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .mapError { AIServiceError.networkError($0) }
            .tryMap { data, response in
                // Log the response
                self.logResponse(data: data, response: response, provider: "Anthropic", endpoint: "models")
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw AIServiceError.unknownError
                }
                
                if httpResponse.statusCode != 200 {
                    if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        // Try to extract error message from Anthropic format: {"type":"error","error":{"type":"authentication_error","message":"..."}}
                        if let errorObj = errorJson["error"] as? [String: Any], 
                           let message = errorObj["message"] as? String {
                            throw AIServiceError.apiError(message)
                        } 
                        // Try another common format: {"error": {"message": "..."}}
                        else if let errorObj = errorJson["error"] as? [String: Any],
                                let message = errorObj["message"] as? String {
                            throw AIServiceError.apiError(message)
                        }
                        // Simple format: {"message": "..."}
                        else if let message = errorJson["message"] as? String {
                            throw AIServiceError.apiError(message)
                        }
                    }
                    // Fallback
                    let responseString = String(data: data, encoding: .utf8) ?? "Unknown error"
                    throw AIServiceError.apiError("Error \(httpResponse.statusCode): \(responseString)")
                }
                
                return data
            }
            .decode(type: AnthropicModelsResponse.self, decoder: JSONDecoder())
            .mapError { error in
                self.logError(error, provider: "Anthropic", endpoint: "models")
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
    
    private func sendGooglePrompt(
        text: String,
        systemPrompt: String? = nil,
        model: String,
        apiKey: String
    ) -> AnyPublisher<String, AIServiceError> {
        let baseURL = "https://generativelanguage.googleapis.com/v1/models/"
        guard let encodedModel = model.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "\(baseURL)\(encodedModel):generateContent?key=\(apiKey)") else {
            return Fail(error: AIServiceError.invalidURL).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Google AI doesn't support system role, so we need to handle it differently
        let finalUserText: String
        if let systemPrompt = systemPrompt, !systemPrompt.isEmpty {
            // Incorporate system prompt into the user message
            finalUserText = "\(systemPrompt)\n\n\(text)"
        } else {
            finalUserText = text
        }
        
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "role": "user",
                    "parts": [["text": finalUserText]]
                ]
            ]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            // Log the request
            logRequest(request, provider: "Google AI", endpoint: "generateContent")
        } catch {
            logError(error, provider: "Google AI", endpoint: "generateContent")
            return Fail(error: AIServiceError.invalidRequestData(error)).eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response in
                // Log the response
                self.logResponse(data: data, response: response, provider: "Google AI", endpoint: "generateContent")
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw AIServiceError.invalidResponse
                }
                
                if httpResponse.statusCode != 200 {
                    if let errorString = String(data: data, encoding: .utf8) {
                        throw AIServiceError.requestFailed(httpResponse.statusCode, errorString)
                    } else {
                        throw AIServiceError.requestFailed(httpResponse.statusCode, "Unknown error")
                    }
                }
                
                return data
            }
            .decode(type: GoogleAIResponse.self, decoder: JSONDecoder())
            .map { response in
                guard let candidate = response.candidates.first,
                      let part = candidate.content.parts.first else {
                    return "No response generated"
                }
                return part.text
            }
            .mapError { error in
                self.logError(error, provider: "Google AI", endpoint: "generateContent")
                if let aiError = error as? AIServiceError {
                    return aiError
                } else if let decodingError = error as? DecodingError {
                    return AIServiceError.decodingError(decodingError)
                } else {
                    return AIServiceError.unknown(error)
                }
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
        
        let request = URLRequest(url: url)
        
        // Log the request
        logRequest(request, provider: "Google AI", endpoint: "models")
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .mapError { AIServiceError.networkError($0) }
            .tryMap { data, response in
                // Log the response
                self.logResponse(data: data, response: response, provider: "Google AI", endpoint: "models")
                
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
                self.logError(error, provider: "Google AI", endpoint: "models")
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
    
    private func sendGroqPrompt(
        text: String,
        systemPrompt: String? = nil,
        model: String,
        apiKey: String
    ) -> AnyPublisher<String, AIServiceError> {
        guard !apiKey.isEmpty else {
            return Fail(error: AIServiceError.invalidAPIKey).eraseToAnyPublisher()
        }
        
        guard let url = URL(string: "https://api.groq.com/openai/v1/chat/completions") else {
            return Fail(error: AIServiceError.invalidURL).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        var messages: [[String: String]] = []
        
        if let systemPrompt = systemPrompt, !systemPrompt.isEmpty {
            messages.append(["role": "system", "content": systemPrompt])
        }
        
        messages.append(["role": "user", "content": text])
        
        let requestBody: [String: Any] = [
            "model": model,
            "messages": messages
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            // Log the request
            logRequest(request, provider: "Groq", endpoint: "chat/completions")
        } catch {
            logError(error, provider: "Groq", endpoint: "chat/completions")
            return Fail(error: AIServiceError.invalidRequestData(error)).eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response in
                // Log the response
                self.logResponse(data: data, response: response, provider: "Groq", endpoint: "chat/completions")
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw AIServiceError.invalidResponse
                }
                
                if httpResponse.statusCode != 200 {
                    if let errorString = String(data: data, encoding: .utf8) {
                        throw AIServiceError.requestFailed(httpResponse.statusCode, errorString)
                    } else {
                        throw AIServiceError.requestFailed(httpResponse.statusCode, "Unknown error")
                    }
                }
                
                return data
            }
            .decode(type: OpenAIResponse.self, decoder: JSONDecoder())
            .map { response in
                guard let choice = response.choices.first else {
                    return "No response generated"
                }
                return choice.message.content
            }
            .mapError { error in
                self.logError(error, provider: "Groq", endpoint: "chat/completions")
                if let aiError = error as? AIServiceError {
                    return aiError
                } else if let decodingError = error as? DecodingError {
                    return AIServiceError.decodingError(decodingError)
                } else {
                    return AIServiceError.unknown(error)
                }
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
        
        // Log the request
        logRequest(request, provider: "Groq", endpoint: "models")
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .mapError { AIServiceError.networkError($0) }
            .tryMap { data, response in
                // Log the response
                self.logResponse(data: data, response: response, provider: "Groq", endpoint: "models")
                
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
                self.logError(error, provider: "Groq", endpoint: "models")
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
    
    private func sendDeepSeekPrompt(
        text: String,
        systemPrompt: String? = nil,
        model: String,
        apiKey: String
    ) -> AnyPublisher<String, AIServiceError> {
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
        
        var messages: [[String: String]] = []
        
        if let systemPrompt = systemPrompt, !systemPrompt.isEmpty {
            messages.append(["role": "system", "content": systemPrompt])
        }
        
        messages.append(["role": "user", "content": text])
        
        let requestBody: [String: Any] = [
            "model": model,
            "messages": messages
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            // Log the request
            logRequest(request, provider: "DeepSeek", endpoint: "chat/completions")
        } catch {
            logError(error, provider: "DeepSeek", endpoint: "chat/completions")
            return Fail(error: AIServiceError.invalidRequestData(error)).eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response in
                // Log the response
                self.logResponse(data: data, response: response, provider: "DeepSeek", endpoint: "chat/completions")
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw AIServiceError.invalidResponse
                }
                
                if httpResponse.statusCode != 200 {
                    if let errorString = String(data: data, encoding: .utf8) {
                        throw AIServiceError.requestFailed(httpResponse.statusCode, errorString)
                    } else {
                        throw AIServiceError.requestFailed(httpResponse.statusCode, "Unknown error")
                    }
                }
                
                return data
            }
            .decode(type: OpenAIResponse.self, decoder: JSONDecoder())
            .map { response in
                guard let choice = response.choices.first else {
                    return "No response generated"
                }
                return choice.message.content
            }
            .mapError { error in
                self.logError(error, provider: "DeepSeek", endpoint: "chat/completions")
                if let aiError = error as? AIServiceError {
                    return aiError
                } else if let decodingError = error as? DecodingError {
                    return AIServiceError.decodingError(decodingError)
                } else {
                    return AIServiceError.unknown(error)
                }
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
        
        // Log the request
        logRequest(request, provider: "DeepSeek", endpoint: "models")
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .mapError { AIServiceError.networkError($0) }
            .tryMap { data, response in
                // Log the response
                self.logResponse(data: data, response: response, provider: "DeepSeek", endpoint: "models")
                
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
                self.logError(error, provider: "DeepSeek", endpoint: "models")
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
    
    private func sendOllamaPrompt(
        text: String,
        systemPrompt: String? = nil,
        model: String,
        endpoint: String
    ) -> AnyPublisher<String, AIServiceError> {
        guard let url = URL(string: "\(endpoint)/api/chat") else {
            return Fail(error: AIServiceError.invalidURL).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var messages: [[String: Any]] = []
        
        if let systemPrompt = systemPrompt, !systemPrompt.isEmpty {
            messages.append(["role": "system", "content": systemPrompt])
        }
        
        messages.append(["role": "user", "content": text])
        
        let requestBody: [String: Any] = [
            "model": model,
            "messages": messages,
            "stream": false
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            // Log the request
            logRequest(request, provider: "Ollama", endpoint: "chat")
        } catch {
            logError(error, provider: "Ollama", endpoint: "chat")
            return Fail(error: AIServiceError.invalidRequestData(error)).eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response in
                // Log the response
                self.logResponse(data: data, response: response, provider: "Ollama", endpoint: "chat")
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw AIServiceError.invalidResponse
                }
                
                if httpResponse.statusCode != 200 {
                    if let errorString = String(data: data, encoding: .utf8) {
                        throw AIServiceError.requestFailed(httpResponse.statusCode, errorString)
                    } else {
                        throw AIServiceError.requestFailed(httpResponse.statusCode, "Unknown error")
                    }
                }
                
                return data
            }
            .decode(type: OllamaChatResponse.self, decoder: JSONDecoder())
            .map { response in
                return response.message.content
            }
            .mapError { error in
                self.logError(error, provider: "Ollama", endpoint: "chat")
                if let aiError = error as? AIServiceError {
                    return aiError
                } else if let decodingError = error as? DecodingError {
                    return AIServiceError.decodingError(decodingError)
                } else {
                    return AIServiceError.unknown(error)
                }
            }
            .eraseToAnyPublisher()
    }
    
    private func fetchOllamaModels(endpoint: String) -> AnyPublisher<[String], AIServiceError> {
        guard let url = URL(string: "\(endpoint)/api/tags") else {
            return Fail(error: AIServiceError.invalidURL).eraseToAnyPublisher()
        }
        
        let request = URLRequest(url: url)
        
        // Log the request
        logRequest(request, provider: "Ollama", endpoint: "tags")
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .mapError { AIServiceError.networkError($0) }
            .tryMap { data, response in
                // Log the response
                self.logResponse(data: data, response: response, provider: "Ollama", endpoint: "tags")
                
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
                self.logError(error, provider: "Ollama", endpoint: "tags")
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
    
    private func sendMistralPrompt(
        text: String,
        systemPrompt: String? = nil,
        model: String,
        apiKey: String
    ) -> AnyPublisher<String, AIServiceError> {
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
        
        var messages: [[String: Any]] = []
        
        if let systemPrompt = systemPrompt, !systemPrompt.isEmpty {
            messages.append(["role": "system", "content": systemPrompt])
        }
        
        messages.append(["role": "user", "content": text])
        
        let requestBody: [String: Any] = [
            "model": model,
            "messages": messages,
            "temperature": 0.7
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            // Log the request
            logRequest(request, provider: "Mistral", endpoint: "chat/completions")
        } catch {
            logError(error, provider: "Mistral", endpoint: "chat/completions")
            return Fail(error: AIServiceError.invalidRequestData(error)).eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response in
                // Log the response
                self.logResponse(data: data, response: response, provider: "Mistral", endpoint: "chat/completions")
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw AIServiceError.invalidResponse
                }
                
                if httpResponse.statusCode != 200 {
                    if let errorString = String(data: data, encoding: .utf8) {
                        throw AIServiceError.requestFailed(httpResponse.statusCode, errorString)
                    } else {
                        throw AIServiceError.requestFailed(httpResponse.statusCode, "Unknown error")
                    }
                }
                
                return data
            }
            .decode(type: MistralResponse.self, decoder: JSONDecoder())
            .map { response in
                guard let choice = response.choices.first else {
                    return "No response generated"
                }
                return choice.message.content
            }
            .mapError { error in
                self.logError(error, provider: "Mistral", endpoint: "chat/completions")
                if let aiError = error as? AIServiceError {
                    return aiError
                } else if let decodingError = error as? DecodingError {
                    return AIServiceError.decodingError(decodingError)
                } else {
                    return AIServiceError.unknown(error)
                }
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
        
        // Log the request
        logRequest(request, provider: "Mistral", endpoint: "models")
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .mapError { AIServiceError.networkError($0) }
            .tryMap { data, response in
                // Log the response
                self.logResponse(data: data, response: response, provider: "Mistral", endpoint: "models")
                
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
                self.logError(error, provider: "Mistral", endpoint: "models")
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

struct OllamaChatResponse: Decodable {
    struct Message: Decodable {
        let content: String
    }
    
    let message: Message
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