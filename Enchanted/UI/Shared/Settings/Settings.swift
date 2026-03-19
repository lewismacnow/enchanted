//
//  Settings.swift
//  Re-Enchanted
//
//  Originally created by Augustinas Malinauskas on 28/12/2023.
//  Forked and maintained by iTomLab (itomlab.co.uk)
//

import SwiftUI
import Combine

struct Settings: View {
    var languageModelStore = LanguageModelStore.shared
    var conversationStore = ConversationStore.shared
    var swiftDataService = SwiftDataService.shared

    @AppStorage("systemPrompt") private var systemPrompt: String = ""
    @AppStorage("vibrations") private var vibrations: Bool = true
    @AppStorage("colorScheme") private var colorScheme = AppColorScheme.system
    @AppStorage("defaultOllamaModel") private var defaultOllamaModel: String = ""
    @AppStorage("appUserInitials") private var appUserInitials: String = ""
    @AppStorage("pingInterval") private var pingInterval: String = "5"
    @AppStorage("voiceIdentifier") private var voiceIdentifier: String = ""

    @StateObject private var speechSynthesiser = SpeechSynthesizer.shared

    @Environment(\.presentationMode) var presentationMode

    private let timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()
    @State private var cancellable: AnyCancellable?

    private func save() {
        // Save provider settings through AppStore
        let settings = AppStore.shared.providerSettings

        // Remove trailing slashes
        var ollamaUri = settings.ollamaUri
        if ollamaUri.last == "/" { ollamaUri = String(ollamaUri.dropLast()) }
        var openAIUri = settings.openAIUri
        if openAIUri.last == "/" { openAIUri = String(openAIUri.dropLast()) }

        var updatedSettings = settings
        updatedSettings.ollamaUri = ollamaUri
        updatedSettings.openAIUri = openAIUri
        AppStore.shared.updateProviderSettings(updatedSettings)

        Task {
            Haptics.shared.mediumTap()
            try? await languageModelStore.loadModels()
        }
        presentationMode.wrappedValue.dismiss()
    }

    private func checkServer() {
        Task {
            let settings = AppStore.shared.providerSettings
            switch settings.provider {
            case .ollama:
                OllamaService.shared.initEndpoint(url: settings.ollamaUri)
                ollamaStatus = await OllamaService.shared.reachable()
            case .openai:
                OpenAIService.shared.updateEndpoint(url: settings.openAIUri, key: settings.openAIKey)
                ollamaStatus = await OpenAIService.shared.reachable()
            }
            try? await languageModelStore.loadModels()
        }
    }

    private func deleteAll() {
        conversationStore.deleteAllConversations()
        Task {
            try? await languageModelStore.deleteAllModels()
        }
    }

    @State var ollamaStatus: Bool?
    var body: some View {
        SettingsView(
            systemPrompt: $systemPrompt,
            vibrations: $vibrations,
            colorScheme: $colorScheme,
            defaultOllamModel: $defaultOllamaModel,
            appUserInitials: $appUserInitials,
            pingInterval: $pingInterval,
            voiceIdentifier: $voiceIdentifier,
            save: save,
            checkServer: checkServer,
            deleteAll: deleteAll,
            ollamaLangugeModels: languageModelStore.models,
            voices: speechSynthesiser.voices
        )
        .frame(maxWidth: 700)
#if os(visionOS)
        .frame(minWidth: 600, minHeight: 800)
#endif
        .onChange(of: defaultOllamaModel) { _, modelName in
            languageModelStore.setModel(modelName: modelName)
        }
        .onAppear {
            cancellable = timer.sink { _ in
                speechSynthesiser.fetchVoices()
            }
        }
        .onDisappear {
            cancellable?.cancel()
        }
    }
}

#Preview {
    Settings()
}
