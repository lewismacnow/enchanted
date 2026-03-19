//
//  WatchNewChatView.swift
//  Re-Enchanted
//
//  New conversation composer for watchOS — model picker and text input.
//

#if os(watchOS)
import SwiftUI

struct WatchNewChatView: View {
    var modelsList: [LanguageModelSD]
    var selectedModel: LanguageModelSD?
    var conversationState: ConversationState
    var onSelectModel: @MainActor (_ model: LanguageModelSD?) -> ()
    var onSendMessageTap: (_ prompt: String, _ model: LanguageModelSD, _ image: Image?, _ trimmingMessageId: String?) -> ()
    var onStopGenerateTap: () -> ()

    @State private var messageText = ""

    private var isLoading: Bool {
        conversationState == .loading
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Model picker
                if !modelsList.isEmpty {
                    WatchModelPickerView(
                        models: modelsList,
                        selectedModel: selectedModel,
                        onSelectModel: onSelectModel
                    )
                }

                if selectedModel == nil {
                    Text("Select a model above to start chatting")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                } else {
                    Text("Type your message below")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("New Chat")
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
