//
//  ModelSelector.swift
//  Re-Enchanted
//
//  Originally created by Augustinas Malinauskas on 11/12/2023.
//

import SwiftUI

struct ModelSelectorView: View {
    var modelsList: [LanguageModelSD]
    var selectedModel: LanguageModelSD?
    var onSelectModel: @MainActor (_ model: LanguageModelSD?) -> ()
    var showChevron = true

    var body: some View {
        Menu {
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
        } label: {
            HStack(alignment: .center, spacing: 4) {
                if let selectedModel = selectedModel {
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
