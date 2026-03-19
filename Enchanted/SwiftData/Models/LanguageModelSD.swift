//
//  ModelSD.swift
//  Re-Enchanted
//
//  Originally created by Augustinas Malinauskas on 10/12/2023.
//

import Foundation
import SwiftData

@Model
final class LanguageModelSD: Identifiable {
    @Attribute(.unique) var name: String
    var isAvailable: Bool = false
    var imageSupport: Bool = false
    var isHidden: Bool = false
    var supportsThinking: Bool = false
    @Attribute var modelProvider: ModelProvider? = ModelProvider.ollama

    @Relationship(deleteRule: .cascade, inverse: \ConversationSD.model)
    var conversations: [ConversationSD]? = []

    init(name: String, imageSupport: Bool = false, supportsThinking: Bool = false, modelProvider: ModelProvider) {
        self.name = name
        self.imageSupport = imageSupport
        self.supportsThinking = supportsThinking
        self.modelProvider = modelProvider
    }

    @Transient var isNotAvailable: Bool {
        isAvailable == false
    }

    @Transient var providerName: String {
        switch modelProvider {
        case .ollama:
            return "Ollama"
        case .openai:
            return "OpenAI"
        case .none:
            return "Unknown"
        }
    }

    // MARK: - Capability Detection

    static func detectThinkingSupport(modelName: String) -> Bool {
        let keywords = ["think", "reasoning", "r1", "qwq", "deepseek-r1", "o1", "o3", "o4"]
        let lower = modelName.lowercased()
        return keywords.contains { lower.contains($0) }
    }

    static func detectVisionSupport(modelName: String) -> Bool {
        let keywords = ["vision", "gpt-4o", "gpt-4-turbo", "claude-3", "llava", "pixtral", "gemini", "mllama"]
        let lower = modelName.lowercased()
        return keywords.contains { lower.contains($0) }
    }
}

// MARK: - Helpers
extension LanguageModelSD {
    var prettyName: String {
        guard let modelName = name.components(separatedBy: ":").first else {
            return name
        }
        return modelName.capitalized
    }

    var prettyVersion: String {
        let components = name.components(separatedBy: ":")
        if components.count >= 2 {
            return components[1]
        }
        return ""
    }

    var supportsImages: Bool {
        if imageSupport {
            return true
        }
        let imageSupportedModels = ["llava"]
        for modelName in imageSupportedModels {
            if name.contains(modelName) {
                return true
            }
        }
        return false
    }

    nonisolated(unsafe) static let sample: [LanguageModelSD] = [
        .init(name: "Llama:latest", modelProvider: .ollama),
        .init(name: "Mistral:latest", modelProvider: .ollama)
    ]
}
