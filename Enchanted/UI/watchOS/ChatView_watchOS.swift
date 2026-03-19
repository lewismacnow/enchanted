//
//  ChatView_watchOS.swift
//  Re-Enchanted
//
//  watchOS root chat view with tab-based navigation.
//

#if os(watchOS)
import SwiftUI

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

    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            WatchConversationListView(
                conversations: conversations,
                selectedConversation: selectedConversation,
                messages: messages,
                modelsList: modelsList,
                selectedModel: selectedModel,
                conversationState: conversationState,
                onSelectModel: onSelectModel,
                onConversationTap: onConversationTap,
                onNewConversationTap: onNewConversationTap,
                onSendMessageTap: onSendMessageTap,
                onStopGenerateTap: onStopGenerateTap,
                onConversationDelete: onConversationDelete
            )
            .tag(0)

            WatchSettingsView()
                .tag(1)
        }
        .tabViewStyle(.verticalPage)
    }
}

#endif
