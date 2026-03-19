//
//  ChatView_watchOS.swift
//  Re-Enchanted
//
//  watchOS root chat view — single NavigationStack with path-based navigation.
//

#if os(watchOS)
import SwiftUI

/// Navigation destinations for watchOS
enum WatchDestination: Hashable {
    case conversation(UUID)
    case newChat
}

struct ChatView_watchOS: View {
    var conversations: [ConversationSD]
    var selectedConversation: ConversationSD?
    var messages: [MessageSD]
    var modelsList: [LanguageModelSD]
    var selectedModel: LanguageModelSD?
    var conversationState: ConversationState
    var onSelectModel: @MainActor (_ model: LanguageModelSD?) -> ()
    var onConversationTap: (_ conversation: ConversationSD) -> ()
    var onNewConversationTap: () -> ()
    var onSendMessageTap: (_ prompt: String, _ model: LanguageModelSD, _ image: Image?, _ trimmingMessageId: String?) -> ()
    var onStopGenerateTap: () -> ()
    var onConversationDelete: (_ conversation: ConversationSD) -> ()

    @State private var navigationPath = NavigationPath()
    @State private var showSettings = false

    var body: some View {
        NavigationStack(path: $navigationPath) {
            WatchConversationListView(
                conversations: conversations,
                onConversationTap: { conversation in
                    onConversationTap(conversation)
                    navigationPath.append(WatchDestination.conversation(conversation.id))
                },
                onNewConversationTap: {
                    onNewConversationTap()
                    navigationPath.append(WatchDestination.newChat)
                },
                onConversationDelete: onConversationDelete,
                onShowSettings: { showSettings = true }
            )
            .navigationDestination(for: WatchDestination.self) { destination in
                switch destination {
                case .conversation(let conversationId):
                    if let conversation = conversations.first(where: { $0.id == conversationId }) {
                        WatchChatDetailView(
                            conversation: conversation,
                            messages: messages,
                            modelsList: modelsList,
                            selectedModel: selectedModel,
                            conversationState: conversationState,
                            onSelectModel: onSelectModel,
                            onConversationTap: onConversationTap,
                            onSendMessageTap: onSendMessageTap,
                            onStopGenerateTap: onStopGenerateTap
                        )
                    }
                case .newChat:
                    WatchNewChatView(
                        modelsList: modelsList,
                        selectedModel: selectedModel,
                        conversationState: conversationState,
                        onSelectModel: onSelectModel,
                        onSendMessageTap: onSendMessageTap,
                        onStopGenerateTap: onStopGenerateTap
                    )
                }
            }
            .sheet(isPresented: $showSettings) {
                WatchSettingsView()
            }
        }
        // When a new conversation is created after sending a message,
        // navigate to it automatically
        .onChange(of: selectedConversation?.id) { oldId, newId in
            if let newId, oldId == nil {
                // A new conversation was just created — replace the newChat destination
                navigationPath = NavigationPath()
                navigationPath.append(WatchDestination.conversation(newId))
            }
        }
    }
}

#endif
