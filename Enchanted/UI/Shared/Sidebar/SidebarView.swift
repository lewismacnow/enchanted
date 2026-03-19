//
//  SidebarView.swift
//  Re-Enchanted
//
//  Originally created by Augustinas Malinauskas on 10/12/2023.
//

import SwiftUI

struct SidebarView: View {
    @Environment(\.openWindow) var openWindow
    var selectedConversation: ConversationSD?
    var conversations: [ConversationSD]
    var onConversationTap: (_ conversation: ConversationSD) -> ()
    var onConversationDelete: (_ conversation: ConversationSD) -> ()
    var onDeleteDailyConversations: (_ date: Date) -> ()
    var onTogglePin: ((_ conversation: ConversationSD) -> Void)?
    @State var showSettings = false
    @State var showCompletions = false
    @State var showKeyboardShortcutas = false
    @State private var searchText = ""

    private func onSettingsTap() {
        showSettings.toggle()
        Haptics.shared.mediumTap()
    }

    private var filteredConversations: [ConversationSD] {
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            return conversations
        }
        let lowered = searchText.lowercased()
        return conversations.filter { conv in
            conv.name.lowercased().contains(lowered) ||
            conv.messages.contains { $0.content.lowercased().contains(lowered) }
        }
    }

    var body: some View {
        VStack {
            // Search bar
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Search conversations...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            ScrollView {
                ConversationHistoryList(
                    selectedConversation: selectedConversation,
                    conversations: filteredConversations,
                    onTap: onConversationTap,
                    onDelete: onConversationDelete,
                    onDeleteDailyConversations: onDeleteDailyConversations,
                    onTogglePin: onTogglePin
                )
            }
            .scrollIndicators(.never)

            Divider()

#if os(macOS)
            SidebarButton(title: "Completions", image: "textformat.abc", onClick: { showCompletions.toggle() })

            SidebarButton(title: "Shortcuts", image: "keyboard.fill", onClick: { showKeyboardShortcutas.toggle() })
#endif

            SidebarButton(title: "Settings", image: "gearshape.fill", onClick: onSettingsTap)
        }
        .padding()
#if os(macOS)
        .focusedSceneValue(\.showSettings, $showSettings)
#endif
        .sheet(isPresented: $showSettings) {
            Settings()
        }
#if os(macOS)
        .sheet(isPresented: $showCompletions) {
            CompletionsEditor()
        }
        .sheet(isPresented: $showKeyboardShortcutas) {
            KeyboardShortcutsDemo()
        }
#endif
    }
}

#Preview {
    SidebarView(selectedConversation: ConversationSD.sample[0], conversations: ConversationSD.sample, onConversationTap: { _ in }, onConversationDelete: { _ in }, onDeleteDailyConversations: { _ in })
}
