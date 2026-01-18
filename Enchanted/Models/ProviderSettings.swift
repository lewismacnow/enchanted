//
//  ProviderSettings.swift
//  Enchanted
//
//  Created by Lewis Mackenzie on 18/01/2026.
//

import Foundation

public struct ProviderSettings: Codable {
    // Nested enum to match usage in SettingsView (ProviderSettings.ProviderType)
    public enum ProviderType: String, CaseIterable, Codable {
        case ollama = "Ollama"
        case openai = "OpenAI"
    }

    public var provider: ProviderType = .ollama
    public var ollamaUri: String = "http://localhost:11434"
    public var ollamaBearerToken: String = "okki"
    public var openAIUri: String = "http://localhost:11434/v1"
    public var openAIKey: String = "not-needed"
    
    // Explicit public init ensures it can be instantiated anywhere
    public init() {}
}
