//
//  ModelStore.swift
//  Re-Enchanted
//
//  Originally created by Augustinas Malinauskas on 10/12/2023.
//  Forked and maintained by iTomLab (itomlab.co.uk)
//

import Foundation
import SwiftData

@Observable
final class LanguageModelStore: @unchecked Sendable {
    static let shared = LanguageModelStore(swiftDataService: SwiftDataService.shared)

    private var swiftDataService: SwiftDataService
    @MainActor var models: [LanguageModelSD] = []
    @MainActor var supportsImages = false
    @MainActor var selectedModel: LanguageModelSD?

    init(swiftDataService: SwiftDataService) {
        self.swiftDataService = swiftDataService
    }

    @MainActor
    func setModel(model: LanguageModelSD?) {
        if let model = model {
            if models.contains(model) {
                selectedModel = model
                supportsImages = model.supportsImages
            }
        } else {
            selectedModel = nil
            supportsImages = false
        }
    }

    @MainActor
    func setModel(modelName: String) {
        for model in models {
            if model.name == modelName {
                setModel(model: model)
                return
            }
        }
        if let lastModel = models.last {
            setModel(model: lastModel)
        }
    }

    func loadModels() async throws {
        var allModels: [LanguageModelSD] = []

        // Determine active provider from settings
        let activeProvider = loadActiveProvider()

        switch activeProvider {
        case .ollama:
            do {
                let ollamaModels = try await OllamaService.shared.getModels()
                let ollamaModelSDs = ollamaModels.map {
                    LanguageModelSD(name: $0.name, imageSupport: $0.imageSupport, modelProvider: .ollama)
                }
                allModels.append(contentsOf: ollamaModelSDs)
            } catch {
                print("Failed to load Ollama models: \(error)")
            }

        case .openai:
            do {
                let openAIModels = try await OpenAIService.shared.getModels()
                let openAIModelSDs = openAIModels.map {
                    LanguageModelSD(name: $0.name, imageSupport: $0.imageSupport, modelProvider: .openai)
                }
                allModels.append(contentsOf: openAIModelSDs)
            } catch {
                print("Failed to load OpenAI models: \(error)")
            }
        }

        // Save all models to local storage
        try await swiftDataService.saveModels(models: allModels)

        // Fetch stored models
        nonisolated(unsafe) let storedModels = (try? await swiftDataService.fetchModels()) ?? []
        let modelNames = allModels.map { $0.name }
        nonisolated(unsafe) let filteredModels = storedModels.filter { modelNames.contains($0.name) }

        await MainActor.run {
            self.models = filteredModels

            // Set first model as selected if none selected
            if self.selectedModel == nil && !self.models.isEmpty {
                self.selectedModel = self.models.first
                self.supportsImages = self.selectedModel?.supportsImages ?? false
            }
        }
    }

    func deleteAllModels() async throws {
        DispatchQueue.main.async {
            self.models = []
            self.selectedModel = nil
            self.supportsImages = false
        }
        try await swiftDataService.deleteModels()
    }

    private func loadActiveProvider() -> ProviderSettings.ProviderType {
        if let data = UserDefaults.standard.data(forKey: "providerSettings"),
           let settings = try? JSONDecoder().decode(ProviderSettings.self, from: data) {
            return settings.provider
        }
        return .ollama
    }
}
