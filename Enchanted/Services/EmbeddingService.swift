//
//  EmbeddingService.swift
//  Re-Enchanted
//
//  Generates text embeddings via Ollama or OpenAI-compatible endpoints.
//  Used by DejaView to create vector representations of OCR text.
//

import Foundation

// MARK: - Response Types

private struct OllamaEmbeddingRequest: Codable {
    let model: String
    let prompt: String
}

private struct OllamaEmbeddingResponse: Codable {
    let embedding: [Double]
}

private struct OpenAIEmbeddingRequest: Codable {
    let model: String
    let input: String
}

private struct OpenAIEmbeddingResponse: Codable {
    let data: [OpenAIEmbeddingData]
}

private struct OpenAIEmbeddingData: Codable {
    let embedding: [Double]
}

// MARK: - Error

struct EmbeddingError: Error, LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

// MARK: - Service

class EmbeddingService: @unchecked Sendable {
    static let shared = EmbeddingService()

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 120
        session = URLSession(configuration: config)
    }

    /// Load current provider settings from UserDefaults.
    private func loadSettings() -> ProviderSettings {
        if let data = UserDefaults.standard.data(forKey: "providerSettings"),
           let settings = try? JSONDecoder().decode(ProviderSettings.self, from: data) {
            return settings
        }
        return ProviderSettings()
    }

    /// Generate an embedding vector for the given text.
    /// Routes to the appropriate backend based on current ProviderSettings.
    func embed(text: String) async throws -> [Float] {
        let settings = loadSettings()

        switch settings.provider {
        case .ollama:
            return try await embedViaOllama(text: text, settings: settings)
        case .openai:
            return try await embedViaOpenAI(text: text, settings: settings)
        }
    }

    // MARK: - Ollama

    private func embedViaOllama(text: String, settings: ProviderSettings) async throws -> [Float] {
        let baseURL = settings.ollamaUri.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let urlString = "\(baseURL)/api/embeddings"

        guard let url = URL(string: urlString) else {
            throw EmbeddingError(message: "Invalid Ollama URL: \(urlString)")
        }

        let body = OllamaEmbeddingRequest(model: "nomic-embed-text", prompt: text)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !settings.ollamaBearerToken.isEmpty {
            request.setValue("Bearer \(settings.ollamaBearerToken)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw EmbeddingError(message: "Invalid response from Ollama embeddings endpoint")
        }
        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw EmbeddingError(message: "Ollama embedding HTTP \(httpResponse.statusCode): \(errorBody)")
        }

        let decoded = try JSONDecoder().decode(OllamaEmbeddingResponse.self, from: data)
        return decoded.embedding.map { Float($0) }
    }

    // MARK: - OpenAI

    private func embedViaOpenAI(text: String, settings: ProviderSettings) async throws -> [Float] {
        guard !settings.openAIUri.isEmpty else {
            throw EmbeddingError(message: "OpenAI endpoint URL not configured")
        }

        let baseURL = settings.openAIUri.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let urlString = "\(baseURL)/embeddings"

        guard let url = URL(string: urlString) else {
            throw EmbeddingError(message: "Invalid OpenAI URL: \(urlString)")
        }

        let body = OpenAIEmbeddingRequest(model: "text-embedding-3-small", input: text)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !settings.openAIKey.isEmpty && settings.openAIKey != "not-needed" {
            request.setValue("Bearer \(settings.openAIKey)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw EmbeddingError(message: "Invalid response from OpenAI embeddings endpoint")
        }
        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw EmbeddingError(message: "OpenAI embedding HTTP \(httpResponse.statusCode): \(errorBody)")
        }

        let decoded = try JSONDecoder().decode(OpenAIEmbeddingResponse.self, from: data)
        guard let first = decoded.data.first else {
            throw EmbeddingError(message: "OpenAI embeddings response contained no data")
        }
        return first.embedding.map { Float($0) }
    }
}
