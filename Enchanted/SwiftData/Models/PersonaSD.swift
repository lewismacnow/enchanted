//
//  PersonaSD.swift
//  Re-Enchanted
//
//  Personas are virtual models backed by a real model with a custom system prompt.
//  E.g., "Code Reviewer" wraps qwen3:latest with a code review system prompt.
//

import Foundation
import SwiftData

@Model
final class PersonaSD: Identifiable {
    @Attribute(.unique) var id: UUID = UUID()
    var name: String
    var icon: String
    var systemPrompt: String
    var isHidden: Bool = false

    @Relationship(deleteRule: .nullify)
    var baseModel: LanguageModelSD?

    init(name: String, icon: String, systemPrompt: String, baseModel: LanguageModelSD? = nil) {
        self.name = name
        self.icon = icon
        self.systemPrompt = systemPrompt
        self.baseModel = baseModel
    }

    @Transient var displayName: String {
        "\(name) (\(baseModel?.prettyName ?? "No model"))"
    }

    nonisolated(unsafe) static let samples: [PersonaSD] = [
        PersonaSD(name: "Code Reviewer", icon: "chevron.left.forwardslash.chevron.right", systemPrompt: "You are an expert code reviewer. Analyze code for bugs, security issues, performance problems, and style. Be thorough but constructive."),
        PersonaSD(name: "Writing Assistant", icon: "pencil.line", systemPrompt: "You are a professional writing assistant. Help improve clarity, grammar, tone, and structure. Suggest improvements while preserving the author's voice."),
        PersonaSD(name: "Explainer", icon: "lightbulb", systemPrompt: "You explain complex topics simply. Use analogies, examples, and step-by-step breakdowns. Adapt your explanation to the user's level of understanding.")
    ]
}
