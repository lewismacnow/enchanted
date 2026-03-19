//
//  WatchConversationListView.swift
//  Re-Enchanted
//
//  Conversation list for watchOS with navigation to chat detail.
//

#if os(watchOS)
import SwiftUI

struct WatchConversationListView: View {
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

    private var recentConversations: [ConversationSD] {
        Array(conversations.sorted { $0.updatedAt > $1.updatedAt }.prefix(20))
    }

    var body: some View {
        NavigationStack {
            List {
                if recentConversations.isEmpty {
                    Text("No conversations yet")
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                } else {
                    ForEach(recentConversations, id: \.id) { conversation in
                        NavigationLink(value: conversation.id) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(conversation.name)
                                    .font(.headline)
                                    .lineLimit(1)
                                HStack(spacing: 4) {
                                    if let modelName = conversation.model?.prettyName {
                                        Text(modelName)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    Text(conversation.updatedAt, style: .relative)
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                onConversationDelete(conversation)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Re-Enchanted")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: onNewConversationTap) {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            .navigationDestination(for: UUID.self) { conversationId in
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
            }
        }
    }
}

#endif
