//
//  OpenAIService.swift
//  Enchanted
//
//  Created by OpenHands AI on 2024.
//

import Foundation
import OpenAI

class OpenAIService: @unchecked Sendable {
    static let shared = OpenAIService()
    
    private var openAI: OpenAI?
    private var baseURL: String = "http://localhost:11434/v1"
    private var apiKey: String = "not-needed"
    
    private init() {
        setupOpenAI()
    }
    
    private func setupOpenAI() {
        // Default to Ollama endpoint
        let localStorageUrl = UserDefaults.standard.string(forKey: "openAIUri")
        let localStorageKey = UserDefaults.standard.string(forKey: "openAIKey")
        
        if let url = localStorageUrl, !url.isEmpty {
            baseURL = url
        }
        
        if let key = localStorageKey, !key.isEmpty {
            apiKey = key
        }
        
        // Initialize OpenAI client
        openAI = OpenAI(
            configuration: OpenAIConfiguration(
                apiKey: apiKey,
                baseURL: baseURL
            )
        )
    }
    
    func updateEndpoint(url: String, key: String? = nil) {
        baseURL = url
        if let key = key {
            apiKey = key
        }
        
        // Reinitialize OpenAI client
        openAI = OpenAI(
            configuration: OpenAIConfiguration(
                apiKey: apiKey,
                baseURL: baseURL
            )
        )
    }
    
    func getModels() async throws -> [LanguageModel] {
        guard let openAI = openAI else {
            throw OpenAIError(message: "OpenAI client not initialized")
        }
        
        let response = try await openAI.models.list()
        let models = response.data.map {
            LanguageModel(
                name: $0.id,
                provider: .openai,
                imageSupport: $0.aliases?.contains(where: { $0.contains("vision") }) ?? false
            )
        }
        return models
    }
    
    func chatCompletion(
        model: String,
        messages: [OpenAI.Chat.ChatCompletionMessage],
        temperature: Double = 0.7,
        maxTokens: Int? = nil,
        topP: Double? = nil,
        frequencyPenalty: Double? = nil,
        presencePenalty: Double? = nil,
        stop: [String]? = nil,
        stream: Bool = false
    ) async throws -> AsyncThrowingStream<OpenAI.Chat.ChatCompletionChunk, Error> {
        guard let openAI = openAI else {
            throw OpenAIError(message: "OpenAI client not initialized")
        }
        
        let request = OpenAI.Chat.ChatCompletionRequest(
            model: model,
            messages: messages,
            temperature: temperature,
            maxTokens: maxTokens,
            topP: topP,
            frequencyPenalty: frequencyPenalty,
            presencePenalty: presencePenalty,
            stop: stop,
            stream: stream
        )
        
        return try await openAI.chat.completions.create(request)
    }
    
    func embeddings(
        model: String,
        input: [String],
        encodingFormat: OpenAI.Embeddings.EmbeddingEncodingFormat? = nil
    ) async throws -> OpenAI.Embeddings.EmbeddingsResponse {
        guard let openAI = openAI else {
            throw OpenAIError(message: "OpenAI client not initialized")
        }
        
        let request = OpenAI.Embeddings.EmbeddingsRequest(
            model: model,
            input: input,
            encodingFormat: encodingFormat
        )
        
        return try await openAI.embeddings.create(request)
    }
    
    func completions(
        model: String,
        prompt: String,
        temperature: Double = 0.7,
        maxTokens: Int? = nil,
        topP: Double? = nil,
        frequencyPenalty: Double? = nil,
        presencePenalty: Double? = nil,
        stop: [String]? = nil,
        stream: Bool = false
    ) async throws -> AsyncThrowingStream<OpenAI.Completions.CompletionChunk, Error> {
        guard let openAI = openAI else {
            throw OpenAIError(message: "OpenAI client not initialized")
        }
        
        let request = OpenAI.Completions.CompletionRequest(
            model: model,
            prompt: prompt,
            temperature: temperature,
            maxTokens: maxTokens,
            topP: topP,
            frequencyPenalty: frequencyPenalty,
            presencePenalty: presencePenalty,
            stop: stop,
            stream: stream
        )
        
        return try await openAI.completions.create(request)
    }
    
    func reachable() async -> Bool {
        guard let openAI = openAI else {
            return false
        }
        
        do {
            // Try to list models to check connectivity
            _ = try await openAI.models.list()
            return true
        } catch {
            return false
        }
    }
}

// Custom error type for OpenAI service
struct OpenAIError: Error, LocalizedError {
    let message: String
    
    var errorDescription: String? {
        return message
    }
}