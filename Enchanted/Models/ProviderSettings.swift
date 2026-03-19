//
//  ProviderSettings.swift
//  Re-Enchanted
//
//  Created by Lewis Mackenzie on 18/01/2026.
//

import Foundation

public struct ProviderSettings: Codable {
    public enum ProviderType: String, CaseIterable, Codable, Sendable {
        case ollama = "Ollama"
        case openai = "OpenAI"
    }

    public var provider: ProviderType = .ollama
    public var ollamaUri: String = "http://localhost:11434"
    public var ollamaBearerToken: String = ""
    public var openAIUri: String = ""
    public var openAIKey: String = ""

    public init() {}
}
