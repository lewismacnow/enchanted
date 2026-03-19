//
//  ConversationHistoryList.swift
//  Re-Enchanted
//
//  Originally created by Augustinas Malinauskas on 10/12/2023.
//

import SwiftUI

struct ConversationGroup: Hashable {
    let date: Date
    var conversations: [ConversationSD]

    static func == (lhs: ConversationGroup, rhs: ConversationGroup) -> Bool {
        lhs.date == rhs.date
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(date)
    }
}

struct ConversationHistoryList: View {
    var selectedConversation: ConversationSD?
    var conversations: [ConversationSD]
    var onTap: (_ conversation: ConversationSD) -> ()
    var onDelete: (_ conversation: ConversationSD) -> ()
    var onDeleteDailyConversations: (_ date: Date) -> ()
    var onTogglePin: ((_ conversation: ConversationSD) -> Void)?

    private var pinnedConversations: [ConversationSD] {
        conversations.filter { $0.isPinned }
    }

    private var unpinnedConversations: [ConversationSD] {
        conversations.filter { !$0.isPinned }
    }

    func groupConversationsByDay(conversations: [ConversationSD]) -> [ConversationGroup] {
        let groupedDictionary = Dictionary(grouping: conversations) { (conversation) -> Date in
            return Calendar.current.startOfDay(for: conversation.updatedAt)
        }

        return groupedDictionary.map { (key, value) in
            ConversationGroup(date: key, conversations: value)
        }.sorted(by: { $0.date > $1.date })
    }

    var conversationGroups: [ConversationGroup] {
        groupConversationsByDay(conversations: unpinnedConversations)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            // Pinned conversations section
            if !pinnedConversations.isEmpty {
                HStack {
                    Image(systemName: "pin.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("Pinned")
                        .font(.system(size: 14))
                        .fontWeight(.semibold)
                        .foregroundColor(Color(.systemGray))
                    Spacer()
                }

                ForEach(pinnedConversations, id: \.self) { conversation in
                    conversationRow(conversation)
                }

                Divider()
            }

            // Regular conversations grouped by day
            ForEach(conversationGroups, id: \.self) { conversationGroup in

                HStack {
                    Text(conversationGroup.date.daysAgoString())
                        .font(.system(size: 14))
                        .fontWeight(.semibold)
                        .foregroundColor(Color(.systemGray))

                    Spacer()
                }
                .contextMenu(menuItems: {
                    Button(role: .destructive, action: { onDeleteDailyConversations(conversationGroup.date) }) {
                        Label("Delete daily conversations", systemImage: "trash")
                    }
                })

                ForEach(conversationGroup.conversations, id: \.self) { dailyConversation in
                    conversationRow(dailyConversation)
                }

                Divider()
            }
        }
    }

    @ViewBuilder
    private func conversationRow(_ conversation: ConversationSD) -> some View {
        Button(action: { onTap(conversation) }) {
            HStack(alignment: .top) {
                Circle()
                    .frame(width: 6, height: 6)
                    .padding(.top, 6)
                    .transition(.opacity)
                    .showIf(selectedConversation == conversation)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(conversation.name)
                            .lineLimit(1)
                            .font(.system(size: 15))
                            .foregroundColor(Color(.label))
                            .transition(.opacity)

                        if conversation.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let modelName = conversation.model?.prettyName {
                        Text(modelName)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
                Spacer()
            }
            .animation(.easeOut(duration: 0.15), value: selectedConversation)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(action: { onTogglePin?(conversation) }) {
                Label(conversation.isPinned ? "Unpin" : "Pin", systemImage: conversation.isPinned ? "pin.slash" : "pin")
            }
            Divider()
            Button(role: .destructive, action: { onDelete(conversation) }) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

#Preview {
    ConversationHistoryList(
        selectedConversation: ConversationSD.sample[0],
        conversations: ConversationSD.sample,
        onTap: { _ in },
        onDelete: { _ in },
        onDeleteDailyConversations: { _ in }
    )
}
