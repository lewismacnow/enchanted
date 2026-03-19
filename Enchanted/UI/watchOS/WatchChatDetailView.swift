//
//  WatchChatDetailView.swift
//  Re-Enchanted
//
//  Chat detail view for watchOS with messages and input.
//

#if os(watchOS)
import SwiftUI

struct WatchChatDetailView: View {
    var conversation: ConversationSD
    var messages: [MessageSD]
    var modelsList: [LanguageModelSD]
    var selectedModel: LanguageModelSD?
    var conversationState: ConversationState
    var onSelectModel: @MainActor (_ model: LanguageModelSD?) -> ()
    var onConversationTap: (_ conversation: ConversationSD) -> ()
    var onSendMessageTap: (_ prompt: String, _ model: LanguageModelSD, _ image: Image?, _ trimmingMessageId: String?) -> ()
    var onStopGenerateTap: () -> ()

    @State private var messageText = ""
    @State private var hasAppeared = false

    private var sortedMessages: [MessageSD] {
        messages.sorted { $0.createdAt < $1.createdAt }
            .filter { $0.role != "system" }
    }

    private var isLoading: Bool {
        conversationState == .loading
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 6) {
                    // Model picker
                    if !modelsList.isEmpty {
                        WatchModelPickerView(
                            models: modelsList,
                            selectedModel: selectedModel,
                            onSelectModel: onSelectModel
                        )
                    }

                    ForEach(sortedMessages, id: \.id) { message in
                        WatchMessageRow(message: message)
                            .id(message.id)
                    }

                    if isLoading, let lastMsg = sortedMessages.last, lastMsg.content.isEmpty {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("Thinking...")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal, 4)
                    }
                }
                .padding(.horizontal, 2)
            }
            .onChange(of: messages.count) { _, _ in
                if let lastId = sortedMessages.last?.id {
                    withAnimation {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }
            .onAppear {
                if !hasAppeared {
                    hasAppeared = true
                    onConversationTap(conversation)
                }
            }
        }
        .navigationTitle(conversation.name)
        .safeAreaInset(edge: .bottom) {
            composeBar
        }
    }

    @ViewBuilder
    private var composeBar: some View {
        VStack(spacing: 4) {
            if isLoading {
                Button(action: onStopGenerateTap) {
                    Label("Stop", systemImage: "stop.fill")
                        .font(.caption)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            } else {
                HStack(spacing: 4) {
                    TextField("Ask...", text: $messageText)
                        .font(.caption)
                        .lineLimit(1...3)

                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    .disabled(messageText.trimmingCharacters(in: .whitespaces).isEmpty || selectedModel == nil)
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial)
    }

    private func sendMessage() {
        guard let model = selectedModel else { return }
        let text = messageText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        messageText = ""
        onSendMessageTap(text, model, nil, nil)
    }
}

#endif
