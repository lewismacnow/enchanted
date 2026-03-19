//
//  WatchModelPickerView.swift
//  Re-Enchanted
//
//  Compact model selector for watchOS.
//

#if os(watchOS)
import SwiftUI

struct WatchModelPickerView: View {
    var models: [LanguageModelSD]
    var selectedModel: LanguageModelSD?
    var onSelectModel: @MainActor (_ model: LanguageModelSD?) -> ()

    @State private var selectedModelName: String = ""

    var body: some View {
        if models.isEmpty {
            Label("No models", systemImage: "exclamationmark.triangle")
                .font(.caption2)
                .foregroundStyle(.secondary)
        } else {
            Picker("Model", selection: $selectedModelName) {
                ForEach(models, id: \.name) { model in
                    Text(model.prettyName)
                        .font(.caption2)
                        .tag(model.name)
                }
            }
            .pickerStyle(.navigationLink)
            .font(.caption)
            .onChange(of: selectedModelName) { _, newValue in
                if let model = models.first(where: { $0.name == newValue }) {
                    onSelectModel(model)
                }
            }
            .onAppear {
                if let model = selectedModel {
                    selectedModelName = model.name
                } else if let first = models.first {
                    selectedModelName = first.name
                }
            }
        }
    }
}

#endif
