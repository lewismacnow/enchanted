//
//  WatchConversationListView.swift
//  Re-Enchanted
//
//  Conversation list for watchOS — a plain List without its own NavigationStack.
//  Navigation is managed by the parent ChatView_watchOS.
//

#if os(watchOS)
import SwiftUI

struct WatchConversationListView: View {
    var conversations: [ConversationSD]
    var onConversationTap: (_ conversation: ConversationSD) -> ()
    var onNewConversationTap: () -> ()
    var onConversationDelete: (_ conversation: ConversationSD) -> ()
    var onShowSettings: () -> ()

    private var recentConversations: [ConversationSD] {
        Array(conversations.sorted { $0.updatedAt > $1.updatedAt }.prefix(20))
    }

    var body: some View {
        List {
            if recentConversations.isEmpty {
                Text("No conversations yet")
                    .foregroundStyle(.secondary)
                    .font(.footnote)
            } else {
                ForEach(recentConversations, id: \.id) { conversation in
                    Button {
                        onConversationTap(conversation)
                    } label: {
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
            ToolbarItem(placement: .topBarLeading) {
                Button(action: onShowSettings) {
                    Image(systemName: "gearshape")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onNewConversationTap) {
                    Image(systemName: "square.and.pencil")
                }
            }
        }
    }
}

#endif
