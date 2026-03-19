//
//  LanguageModel.swift
//  Re-Enchanted
//
//  Originally created by Augustinas Malinauskas on 12/05/2024.
//

import Foundation

struct LanguageModel {
    var name: String
    var provider: ModelProvider
    var imageSupport: Bool
    var thinkingSupport: Bool
}

enum ModelProvider: Codable, CaseIterable {
    case ollama
    case openai
}
