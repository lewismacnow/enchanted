//
//  OpenAIService.swift
//  Re-Enchanted
//
//  OpenAI-compatible API service using URLSession.
//  Works with any OpenAI-compatible endpoint (OpenAI, LM Studio, Ollama /v1, etc.)
//

import Foundation

// MARK: - API Types

struct OpenAIChatMessage: Codable {
    let role: String
    var content: OpenAIChatContent

    enum CodingKeys: String, CodingKey {
        case role, content
    }

    init(role: String, text: String) {
        self.role = role
        self.content = .text(text)
    }

    init(role: String, parts: [OpenAIContentPart]) {
        self.role = role
        self.content = .parts(parts)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(role, forKey: .role)
        switch content {
        case .text(let text):
            try container.encode(text, forKey: .content)
        case .parts(let parts):
            try container.encode(parts, forKey: .content)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        role = try container.decode(String.self, forKey: .role)
        if let text = try? container.decode(String.self, forKey: .content) {
            content = .text(text)
        } else if let parts = try? container.decode([OpenAIContentPart].self, forKey: .content) {
            content = .parts(parts)
        } else {
            content = .text("")
        }
    }
}

enum OpenAIChatContent {
    case text(String)
    case parts([OpenAIContentPart])
}

struct OpenAIContentPart: Codable {
    let type: String
    var text: String?
    var image_url: OpenAIImageURL?

    static func textPart(_ text: String) -> OpenAIContentPart {
        OpenAIContentPart(type: "text", text: text)
    }

    static func imagePart(base64Data: String, mimeType: String = "image/jpeg") -> OpenAIContentPart {
        OpenAIContentPart(
            type: "image_url",
            image_url: OpenAIImageURL(url: "data:\(mimeType);base64,\(base64Data)")
        )
    }
}

struct OpenAIImageURL: Codable {
    let url: String
}

struct OpenAIChatRequest: Codable {
    let model: String
    let messages: [OpenAIChatMessage]
    let stream: Bool
    var temperature: Double?
    var max_tokens: Int?
    var top_p: Double?
    var frequency_penalty: Double?
    var presence_penalty: Double?
}

struct OpenAIModelResponse: Codable {
    let data: [OpenAIModel]
}

struct OpenAIModel: Codable {
    let id: String
    let owned_by: String?
}

struct OpenAIChatResponse: Codable {
    let id: String?
    let choices: [OpenAIChatChoice]
}

struct OpenAIChatChoice: Codable {
    let message: OpenAIChatResponseMessage?
    let finish_reason: String?
}

struct OpenAIChatResponseMessage: Codable {
    let role: String?
    let content: String?
}

// SSE streaming types
struct OpenAIChatStreamChunk: Codable {
    let id: String?
    let choices: [OpenAIStreamChoice]?
}

struct OpenAIStreamChoice: Codable {
    let delta: OpenAIStreamDelta?
    let finish_reason: String?
}

struct OpenAIStreamDelta: Codable {
    let role: String?
    let content: String?
}

// MARK: - Error

struct OpenAIError: Error, LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

// MARK: - Service

class OpenAIService: @unchecked Sendable {
    static let shared = OpenAIService()

    private var baseURL: String = ""
    private var apiKey: String = ""
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120
        config.timeoutIntervalForResource = 300
        session = URLSession(configuration: config)
        loadSettings()
    }

    private func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: "providerSettings"),
           let settings = try? JSONDecoder().decode(ProviderSettings.self, from: data) {
            baseURL = settings.openAIUri
            apiKey = settings.openAIKey
        }
    }

    func updateEndpoint(url: String, key: String) {
        baseURL = url
        apiKey = key
    }

    // MARK: - Models

    func getModels() async throws -> [LanguageModel] {
        loadSettings()
        guard !baseURL.isEmpty else {
            throw OpenAIError(message: "OpenAI endpoint URL not configured")
        }

        let urlString = baseURL.hasSuffix("/") ? "\(baseURL)models" : "\(baseURL)/models"
        guard let url = URL(string: urlString) else {
            throw OpenAIError(message: "Invalid URL: \(urlString)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        applyHeaders(&request)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError(message: "Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw OpenAIError(message: "HTTP \(httpResponse.statusCode): \(body)")
        }

        let modelResponse = try JSONDecoder().decode(OpenAIModelResponse.self, from: data)

        return modelResponse.data.map { model in
            let supportsVision = detectVisionSupport(modelId: model.id)
            return LanguageModel(
                name: model.id,
                provider: .openai,
                imageSupport: supportsVision
            )
        }
    }

    // MARK: - Chat Completion (Streaming)

    func streamChat(
        model: String,
        messages: [OpenAIChatMessage],
        temperature: Double = 0.7
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    self.loadSettings()
                    guard !self.baseURL.isEmpty else {
                        continuation.finish(throwing: OpenAIError(message: "OpenAI endpoint URL not configured"))
                        return
                    }

                    let urlString = self.baseURL.hasSuffix("/") ? "\(self.baseURL)chat/completions" : "\(self.baseURL)/chat/completions"
                    guard let url = URL(string: urlString) else {
                        continuation.finish(throwing: OpenAIError(message: "Invalid URL: \(urlString)"))
                        return
                    }

                    let chatRequest = OpenAIChatRequest(
                        model: model,
                        messages: messages,
                        stream: true,
                        temperature: temperature
                    )

                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.httpBody = try JSONEncoder().encode(chatRequest)
                    self.applyHeaders(&request)
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

                    let (bytes, response) = try await self.session.bytes(for: request)

                    guard let httpResponse = response as? HTTPURLResponse else {
                        continuation.finish(throwing: OpenAIError(message: "Invalid response"))
                        return
                    }

                    guard httpResponse.statusCode == 200 else {
                        var errorBody = ""
                        for try await line in bytes.lines {
                            errorBody += line
                        }
                        continuation.finish(throwing: OpenAIError(message: "HTTP \(httpResponse.statusCode): \(errorBody)"))
                        return
                    }

                    for try await line in bytes.lines {
                        guard !Task.isCancelled else {
                            continuation.finish()
                            return
                        }

                        // SSE format: "data: {...}" or "data: [DONE]"
                        let trimmed = line.trimmingCharacters(in: .whitespaces)

                        guard trimmed.hasPrefix("data: ") else { continue }

                        let jsonString = String(trimmed.dropFirst(6))

                        if jsonString == "[DONE]" {
                            continuation.finish()
                            return
                        }

                        guard let jsonData = jsonString.data(using: .utf8) else { continue }

                        if let chunk = try? JSONDecoder().decode(OpenAIChatStreamChunk.self, from: jsonData),
                           let choices = chunk.choices {
                            for choice in choices {
                                if let content = choice.delta?.content {
                                    continuation.yield(content)
                                }
                            }
                        }
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Reachability

    func reachable() async -> Bool {
        loadSettings()
        guard !baseURL.isEmpty else { return false }

        let urlString = baseURL.hasSuffix("/") ? "\(baseURL)models" : "\(baseURL)/models"
        guard let url = URL(string: urlString) else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 5
        applyHeaders(&request)

        do {
            let (_, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { return false }
            return httpResponse.statusCode == 200
        } catch {
            return false
        }
    }

    // MARK: - Private Helpers

    private func applyHeaders(_ request: inout URLRequest) {
        if !apiKey.isEmpty && apiKey != "not-needed" {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
    }

    private func detectVisionSupport(modelId: String) -> Bool {
        let visionKeywords = ["vision", "gpt-4o", "gpt-4-turbo", "claude-3", "llava", "pixtral", "gemini"]
        let lowerId = modelId.lowercased()
        return visionKeywords.contains { lowerId.contains($0) }
    }
}
