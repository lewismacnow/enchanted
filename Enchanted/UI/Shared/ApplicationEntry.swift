//
//  ApplicationEntry.swift
//  Re-Enchanted
//
//  Originally created by Augustinas Malinauskas on 12/02/2024.
//

import SwiftUI
import SwiftData

struct ApplicationEntry: View {
    @AppStorage("colorScheme") private var colorScheme: AppColorScheme = .system
    @State private var languageModelStore = LanguageModelStore.shared
    @State private var conversationStore = ConversationStore.shared
    #if !os(watchOS)
    @State private var completionsStore = CompletionsStore.shared
    #endif
    @State private var personaStore = PersonaStore.shared
    @State private var appStore = AppStore.shared

    var body: some View {
        VStack {
            #if os(watchOS)
            Chat(languageModelStore: languageModelStore, conversationStore: conversationStore, appStore: appStore)
            #else
            switch appStore.appState {
            case .chat:
                Chat(languageModelStore: languageModelStore, conversationStore: conversationStore, appStore: appStore)
            case .voice:
                Voice(languageModelStore: languageModelStore, conversationStore: conversationStore, appStore: appStore)
            }
            #endif
        }
        .task {
            Task.detached {
                do {
                    try await languageModelStore.loadModels()
                } catch {
                    print("Failed to load models: \(error)")
                }
                do {
                    try await conversationStore.loadConversations()
                } catch {
                    print("Failed to load conversations: \(error)")
                }
                #if !os(watchOS)
                await MainActor.run {
                    completionsStore.load()
                }
                #endif
                await personaStore.loadPersonas()
            }
        }
        .preferredColorScheme(colorScheme.toiOSFormat)
    }
}
