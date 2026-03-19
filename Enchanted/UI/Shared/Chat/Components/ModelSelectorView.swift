//
//  ModelSelector.swift
//  Re-Enchanted
//
//  Originally created by Augustinas Malinauskas on 11/12/2023.
//

#if !os(watchOS)
import SwiftUI

struct ModelSelectorView: View {
    var modelsList: [LanguageModelSD]
    var personas: [PersonaSD] = []
    var selectedModel: LanguageModelSD?
    var activePersona: PersonaSD?
    var onSelectModel: @MainActor (_ model: LanguageModelSD?) -> ()
    var onSelectPersona: (@MainActor (_ persona: PersonaSD) -> Void)?
    var showChevron = true

    var body: some View {
        Menu {
            Section("Models") {
                ForEach(modelsList, id: \.self) { model in
                    Button(action: {
                        withAnimation(.easeOut) {
                            onSelectModel(model)
                        }
                    }) {
                        Label {
                            HStack(spacing: 6) {
                                Text(model.name)
                                    .font(.body)
                                if model.supportsImages {
                                    Image(systemName: "eye.fill")
                                        .font(.caption2)
                                }
                                if model.supportsThinking {
                                    Image(systemName: "brain.head.profile")
                                        .font(.caption2)
                                }
                            }
                        } icon: {
                            Image(systemName: model.modelProvider == .openai ? "globe" : "server.rack")
                        }
                        .tag(model.name)
                    }
                }
            }

            if !personas.isEmpty {
                Divider()
                Section("Personas") {
                    ForEach(personas) { persona in
                        Button(action: {
                            withAnimation(.easeOut) {
                                onSelectPersona?(persona)
                            }
                        }) {
                            Label {
                                HStack(spacing: 6) {
                                    Text(persona.name)
                                        .font(.body)
                                    if let model = persona.baseModel {
                                        Text("(\(model.prettyName))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            } icon: {
                                Image(systemName: persona.icon)
                            }
                        }
                    }
                }
            }
        } label: {
            HStack(alignment: .center, spacing: 4) {
                if let persona = activePersona {
                    HStack(alignment: .center, spacing: 5) {
                        Image(systemName: persona.icon)
                            .font(.caption)
                        Text(persona.name)
                            .font(.body)
                    }
                } else if let selectedModel = selectedModel {
                    HStack(alignment: .center, spacing: 5) {
#if os(macOS) || os(visionOS)
                        Text(selectedModel.name)
                            .font(.body)
#elseif os(iOS)
                        Text(selectedModel.prettyName)
                            .font(.body)
                            .foregroundColor(Color.labelCustom)

                        Text(selectedModel.prettyVersion)
                            .font(.subheadline)
                            .foregroundColor(Color.gray3Custom)
#endif
                        ModelCapabilityBadges(
                            supportsVision: selectedModel.supportsImages,
                            supportsThinking: selectedModel.supportsThinking
                        )
                    }
                }

                Image(systemName: "chevron.down")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 10)
                    .foregroundColor(Color(.label))
                    .showIf(showChevron)
            }
            .accessibilityLabel("Select model")
            .accessibilityHint("Opens model picker with available LLM models and personas")
        }
    }
}

#Preview {
    ModelSelectorView(
        modelsList: LanguageModelSD.sample,
        selectedModel: LanguageModelSD.sample[0],
        onSelectModel: { _ in },
        showChevron: false
    )
}
#endif
