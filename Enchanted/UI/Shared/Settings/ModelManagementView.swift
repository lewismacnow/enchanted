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
        VStack(alignment: .leading, spacing: 0) {
            Text("Models")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top, 12)

            Text("Toggle visibility to hide models from the chat selector. Embedding models and unused models can be hidden.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.top, 4)
                .padding(.bottom, 8)

            TextField("Search models...", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
                .padding(.bottom, 8)

            List {
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
                }
            }
            .listStyle(.plain)
        }
    }
}

#Preview {
    ModelManagementView()
        .frame(width: 500, height: 400)
}
