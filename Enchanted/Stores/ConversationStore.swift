//
//  ConversationStore.swift
//  Re-Enchanted
//
//  Originally created by Augustinas Malinauskas on 10/12/2023.
//  Forked and maintained by iTomLab (itomlab.co.uk)
//

import Foundation
import SwiftData
#if !os(watchOS)
@preconcurrency import OllamaKit
import Combine
#endif
import SwiftUI

@Observable
final class ConversationStore: @unchecked Sendable {
    static let shared = ConversationStore(swiftDataService: SwiftDataService.shared)

    private let swiftDataService: SwiftDataService
    #if !os(watchOS)
    private var generation: AnyCancellable?
    #endif
    private var openAITask: Task<Void, Never>?

    private var currentMessageBuffer: String = ""
    private let throttler = Throttler(delay: 0.1)

    @MainActor var conversationState: ConversationState = .completed
    @MainActor var conversations: [ConversationSD] = []
    @MainActor var selectedConversation: ConversationSD?
    @MainActor var messages: [MessageSD] = []
    @MainActor private var thinkingStartTime: Date?

    init(swiftDataService: SwiftDataService) {
        self.swiftDataService = swiftDataService
    }

    func loadConversations() async throws {
        nonisolated(unsafe) let fetchedConversations = try await swiftDataService.fetchConversations()
        await MainActor.run {
            self.conversations = fetchedConversations
        }
    }

    func deleteAllConversations() {
        Task {
            await MainActor.run {
                self.messages = []
                self.selectedConversation = nil
            }
            try? await swiftDataService.deleteConversations()
            try? await swiftDataService.deleteMessages()
            try? await loadConversations()
        }
    }

    func deleteDailyConversations(_ date: Date) {
        Task {
            await MainActor.run {
                self.selectedConversation = nil
                self.messages = []
            }
            try? await swiftDataService.deleteConversations(date)
            try? await loadConversations()
        }
    }

    func create(_ conversation: ConversationSD) async throws {
        try await swiftDataService.createConversation(conversation)
    }

    @MainActor
    func togglePin(_ conversation: ConversationSD) {
        conversation.isPinned.toggle()
        Task {
            try? await swiftDataService.updateConversation(conversation)
            try? await loadConversations()
        }
    }

    @MainActor
    func renameConversation(_ conversation: ConversationSD, newName: String) {
        guard !newName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        conversation.name = newName
        Task {
            try? await swiftDataService.renameConversation(conversation)
            try? await loadConversations()
        }
    }

    /// Search conversations by name or message content.
    func searchConversations(query: String) async -> [ConversationSD] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        do {
            nonisolated(unsafe) let allConversations = try await swiftDataService.fetchConversations()
            let lowered = query.lowercased()
            return allConversations.filter { conv in
                if conv.name.lowercased().contains(lowered) { return true }
                return conv.messages.contains { $0.content.lowercased().contains(lowered) }
            }
        } catch {
            return []
        }
    }

    func reloadConversation(_ conversation: ConversationSD) async throws {
        nonisolated(unsafe) let (fetchedMessages, fetchedConversation) = try await (
            swiftDataService.fetchMessages(conversation.id),
            swiftDataService.getConversation(conversation.id)
        )

        await MainActor.run {
            self.messages = fetchedMessages
            self.selectedConversation = fetchedConversation
        }
    }

    func selectConversation(_ conversation: ConversationSD) async throws {
        try await reloadConversation(conversation)
    }

    func delete(_ conversation: ConversationSD) async throws {
        try await swiftDataService.deleteConversation(conversation)
        nonisolated(unsafe) let fetchedConversations = try await swiftDataService.fetchConversations()
        await MainActor.run {
            self.selectedConversation = nil
            self.conversations = fetchedConversations
        }
    }

    @MainActor func stopGenerate() {
        #if !os(watchOS)
        generation?.cancel()
        #endif
        openAITask?.cancel()
        openAITask = nil
        handleComplete()
        withAnimation {
            conversationState = .completed
        }
    }

    @MainActor
    func sendPrompt(userPrompt: String, model: LanguageModelSD, image: Image? = nil, systemPrompt: String = "", trimmingMessageId: String? = nil) {
        guard userPrompt.trimmingCharacters(in: .whitespacesAndNewlines).count > 0 else { return }

        let conversation = selectedConversation ?? ConversationSD(name: userPrompt)
        conversation.updatedAt = Date.now
        conversation.model = model

        // Trim conversation if editing a previous message
        if let trimmingMessageId = trimmingMessageId {
            let trimmed = conversation.messages
                .sorted { $0.createdAt < $1.createdAt }
                .prefix(while: { $0.id.uuidString != trimmingMessageId })
            conversation.messages = Array(trimmed)
        }

        // Add system prompt to first message in conversation
        var systemMessage: MessageSD?
        if !systemPrompt.isEmpty && conversation.messages.isEmpty {
            let msg = MessageSD(content: systemPrompt, role: "system")
            msg.conversation = conversation
            systemMessage = msg
        }

        let userMessage = MessageSD(content: userPrompt, role: "user", image: image?.render()?.compressImageData())
        userMessage.conversation = conversation

        let assistantMessage = MessageSD(content: "", role: "assistant")
        assistantMessage.conversation = conversation

        conversationState = .loading

        let provider = model.modelProvider ?? .ollama

        Task {
            do {
                try await swiftDataService.updateConversation(conversation)
                if let systemMessage {
                    try await swiftDataService.createMessage(systemMessage)
                }
                try await swiftDataService.createMessage(userMessage)
                try await swiftDataService.createMessage(assistantMessage)
                try await reloadConversation(conversation)
                try? await loadConversations()

                switch provider {
                case .ollama:
                    #if os(watchOS)
                    await MainActor.run {
                        self.handleError("Ollama is not supported on Apple Watch. Use an OpenAI-compatible provider in Settings.")
                    }
                    #else
                    await sendViaOllama(model: model, conversation: conversation, image: image)
                    #endif
                case .openai:
                    await sendViaOpenAI(model: model, conversation: conversation, image: image)
                }
            } catch {
                self.handleError("Failed to save messages: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Ollama Provider

    #if !os(watchOS)
    @MainActor
    private func sendViaOllama(model: LanguageModelSD, conversation: ConversationSD, image: Image?) async {
        let sortedMessages = conversation.messages.sorted { $0.createdAt < $1.createdAt }

        var messageHistory: [OKChatRequestData.Message] = []

        for msg in sortedMessages {
            if msg.role == "assistant" && msg.content.isEmpty && msg == sortedMessages.last {
                continue
            }

            let role = OKChatRequestData.Message.Role(rawValue: msg.role) ?? .assistant

            if msg.role == "user", let imageData = msg.image, !imageData.isEmpty {
                let base64 = imageData.base64EncodedString()
                messageHistory.append(OKChatRequestData.Message(role: role, content: msg.content, images: [base64]))
            } else if msg.role == "user" && image != nil && sortedMessages.count >= 2 && msg == sortedMessages[sortedMessages.count - 2] {
                if let rendered = image?.render() {
                    let base64 = rendered.convertImageToBase64String()
                    messageHistory.append(OKChatRequestData.Message(role: role, content: msg.content, images: [base64]))
                } else {
                    messageHistory.append(OKChatRequestData.Message(role: role, content: msg.content))
                }
            } else {
                messageHistory.append(OKChatRequestData.Message(role: role, content: msg.content))
            }
        }

        if await OllamaService.shared.ollamaKit.reachable() {
            let capturedHistory = messageHistory
            let modelName = model.name

            DispatchQueue.global(qos: .background).async { [weak self] in
                guard let self = self else { return }
                var request = OKChatRequestData(model: modelName, messages: capturedHistory)
                request.options = OKCompletionOptions(temperature: 0)

                self.generation = OllamaService.shared.ollamaKit.chat(data: request)
                    .sink(receiveCompletion: { [weak self] completion in
                        guard let self = self else { return }
                        Task { @MainActor in
                            switch completion {
                            case .finished:
                                self.handleComplete()
                            case .failure(let error):
                                self.handleError(error.localizedDescription)
                            }
                        }
                    }, receiveValue: { [weak self] response in
                        guard let self = self else { return }
                        Task { @MainActor in
                            self.handleOllamaReceive(response)
                        }
                    })
            }
        } else {
            self.handleError("Ollama server unreachable")
        }
    }
    #endif

    // MARK: - OpenAI Provider

    @MainActor
    private func sendViaOpenAI(model: LanguageModelSD, conversation: ConversationSD, image: Image?) async {
        let sortedMessages = conversation.messages.sorted { $0.createdAt < $1.createdAt }

        var openAIMessages: [OpenAIChatMessage] = []

        for (index, msg) in sortedMessages.enumerated() {
            if msg.role == "assistant" && msg.content.isEmpty && index == sortedMessages.count - 1 {
                continue
            }

            let isLastUserMessage = sortedMessages.count >= 2 && index == sortedMessages.count - 2 && msg.role == "user"
            let hasStoredImage = msg.role == "user" && msg.image != nil && !msg.image!.isEmpty
            let hasFreshImage = isLastUserMessage && image != nil && model.supportsImages

            if hasStoredImage {
                let base64 = msg.image!.base64EncodedString()
                let parts: [OpenAIContentPart] = [
                    .textPart(msg.content),
                    .imagePart(base64Data: base64)
                ]
                openAIMessages.append(OpenAIChatMessage(role: msg.role, parts: parts))
            } else if hasFreshImage, let renderedImage = image?.render() {
                let base64 = renderedImage.convertImageToBase64String()
                let parts: [OpenAIContentPart] = [
                    .textPart(msg.content),
                    .imagePart(base64Data: base64)
                ]
                openAIMessages.append(OpenAIChatMessage(role: msg.role, parts: parts))
            } else {
                openAIMessages.append(OpenAIChatMessage(role: msg.role, text: msg.content))
            }
        }

        let stream = OpenAIService.shared.streamChat(
            model: model.name,
            messages: openAIMessages,
            temperature: 0.7
        )

        openAITask = Task { @MainActor [weak self] in
            do {
                for try await content in stream {
                    guard !Task.isCancelled else { break }
                    self?.handleOpenAIReceive(content)
                }
                self?.handleComplete()
            } catch {
                if !Task.isCancelled {
                    self?.handleError(error.localizedDescription)
                }
            }
        }
    }

    // MARK: - Response Handlers

    #if !os(watchOS)
    @MainActor
    private func handleOllamaReceive(_ response: OKChatResponse) {
        guard !messages.isEmpty else { return }

        if let responseContent = response.message?.content {
            currentMessageBuffer += responseContent
            let bufferedContent = currentMessageBuffer

            throttler.throttle { [weak self] in
                guard let self = self, let lastMessage = self.messages.last else { return }
                lastMessage.content.append(bufferedContent)
                self.trackThinkingDuration(for: lastMessage)
                self.currentMessageBuffer = ""
            }
        }
    }
    #endif

    @MainActor
    private func handleOpenAIReceive(_ content: String) {
        guard !messages.isEmpty else { return }

        currentMessageBuffer += content
        let bufferedContent = currentMessageBuffer

        throttler.throttle { [weak self] in
            guard let self = self, let lastMessage = self.messages.last else { return }
            lastMessage.content.append(bufferedContent)
            self.trackThinkingDuration(for: lastMessage)
            self.currentMessageBuffer = ""
        }
    }

    @MainActor
    private func trackThinkingDuration(for message: MessageSD) {
        let content = message.content
        if content.contains("<think>") && thinkingStartTime == nil {
            thinkingStartTime = Date()
        }
        if content.contains("</think>"), let startTime = thinkingStartTime {
            message.thinkingDuration = Date().timeIntervalSince(startTime)
            thinkingStartTime = nil
        }
    }

    @MainActor
    private func handleError(_ errorMessage: String) {
        guard let lastMessage = messages.last else { return }
        lastMessage.error = true
        lastMessage.done = false

        Task(priority: .background) {
            try? await swiftDataService.updateMessage(lastMessage)
        }

        withAnimation {
            conversationState = .error(message: errorMessage)
        }
    }

    @MainActor
    private func handleComplete() {
        // Flush any remaining buffered content before marking complete
        if !currentMessageBuffer.isEmpty, let lastMessage = messages.last {
            lastMessage.content.append(currentMessageBuffer)
            trackThinkingDuration(for: lastMessage)
            currentMessageBuffer = ""
        }

        guard let lastMessage = messages.last else { return }
        lastMessage.error = false
        lastMessage.done = true

        // Finalize thinking duration if stream ended mid-think
        if let startTime = thinkingStartTime {
            lastMessage.thinkingDuration = Date().timeIntervalSince(startTime)
            thinkingStartTime = nil
        }

        Task(priority: .background) {
            try? await self.swiftDataService.updateMessage(lastMessage)
        }

        withAnimation {
            conversationState = .completed
        }
    }
}
