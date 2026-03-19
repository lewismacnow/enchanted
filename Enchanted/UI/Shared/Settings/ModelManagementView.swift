#if !os(watchOS)
//
//  ModelManagementView.swift
//  Re-Enchanted
//
//  Allows users to show/hide models and see their capabilities.
//

import SwiftUI

struct ModelManagementView: View {
    @State private var languageModelStore = LanguageModelStore.shared
    @State private var searchText = ""

    private var filteredModels: [LanguageModelSD] {
        if searchText.isEmpty {
            return languageModelStore.models
        }
        return languageModelStore.models.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Models")
                .font(.headline)

            Text("Toggle visibility to hide models from the chat selector. Embedding models and unused models can be hidden.")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("Search models...", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            if filteredModels.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "cpu")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text(searchText.isEmpty ? "No models loaded" : "No matching models")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            } else {
                ForEach(filteredModels, id: \.name) { model in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(model.prettyName)
                                    .font(.body)
                                    .foregroundStyle(model.isHidden ? .secondary : .primary)

                                ModelCapabilityBadges(
                                    supportsVision: model.supportsImages,
                                    supportsThinking: model.supportsThinking
                                )
                            }

                            HStack(spacing: 8) {
                                Text(model.name)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)

                                Text(model.providerName)
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.secondary.opacity(0.15))
                                    .clipShape(Capsule())
                            }
                        }

                        Spacer()

                        Toggle("", isOn: Binding(
                            get: { !model.isHidden },
                            set: { _ in
                                languageModelStore.toggleModelVisibility(model)
                            }
                        ))
                        .labelsHidden()
                        .help(model.isHidden ? "Show in model selector" : "Hide from model selector")
                    }
                    .padding(.vertical, 4)

                    if model.name != filteredModels.last?.name {
                        Divider()
                    }
                }
            }
        }
    }
}

#Preview {
    ModelManagementView()
        .frame(width: 500, height: 400)
}
#endif
