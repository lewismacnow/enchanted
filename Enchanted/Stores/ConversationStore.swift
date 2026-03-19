//
//  ConversationStore.swift
//  Re-Enchanted
//
//  Originally created by Augustinas Malinauskas on 10/12/2023.
//  Forked and maintained by iTomLab (itomlab.co.uk)
//

import Foundation
import SwiftData
@preconcurrency import OllamaKit
import Combine
import SwiftUI

@Observable
final class ConversationStore: Sendable {
    static let shared = ConversationStore(swiftDataService: SwiftDataService.shared)

    private var swiftDataService: SwiftDataService
    private var generation: AnyCancellable?
    private var openAITask: Task<Void, Never>?

    private var currentMessageBuffer: String = ""
#if os(macOS)
    private let throttler = Throttler(delay: 0.1)
#else
    private let throttler = Throttler(delay: 0.1)
#endif

    @MainActor var conversationState: ConversationState = .completed
    @MainActor var conversations: [ConversationSD] = []
    @MainActor var selectedConversation: ConversationSD?
    @MainActor var messages: [MessageSD] = []

    init(swiftDataService: SwiftDataService) {
        self.swiftDataService = swiftDataService
    }

    func loadConversations() async throws {
        let fetchedConversations = try await swiftDataService.fetchConversations()
        DispatchQueue.main.async {
            self.conversations = fetchedConversations
        }
    }

    func deleteAllConversations() {
        Task {
            DispatchQueue.main.async { [weak self] in
                self?.messages = []
                self?.selectedConversation = nil
            }
            try? await swiftDataService.deleteConversations()
            try? await swiftDataService.deleteMessages()
            try? await loadConversations()
        }
    }

    func deleteDailyConversations(_ date: Date) {
        Task {
            DispatchQueue.main.async { [self] in
                selectedConversation = nil
                messages = []
            }
            try? await swiftDataService.deleteConversations()
            try? await loadConversations()
        }
    }

    func create(_ conversation: ConversationSD) async throws {
        try await swiftDataService.createConversation(conversation)
    }

    func reloadConversation(_ conversation: ConversationSD) async throws {
        let (messages, selectedConversation) = try await (
            swiftDataService.fetchMessages(conversation.id),
            swiftDataService.getConversation(conversation.id)
        )

        DispatchQueue.main.async {
            self.messages = messages
            self.selectedConversation = selectedConversation
        }
    }

    func selectConversation(_ conversation: ConversationSD) async throws {
        try await reloadConversation(conversation)
    }

    func delete(_ conversation: ConversationSD) async throws {
        try await swiftDataService.deleteConversation(conversation)
        let fetchedConversations = try await swiftDataService.fetchConversations()
        DispatchQueue.main.async {
            self.selectedConversation = nil
            self.conversations = fetchedConversations
        }
    }

    @MainActor func stopGenerate() {
        generation?.cancel()
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

        /// trim conversation if on edit mode
        if let trimmingMessageId = trimmingMessageId {
            conversation.messages = conversation.messages
                .sorted { $0.createdAt < $1.createdAt }
                .prefix(while: { $0.id.uuidString != trimmingMessageId })
        }

        /// add system prompt to very first message in the conversation
        if !systemPrompt.isEmpty && conversation.messages.isEmpty {
            let systemMessage = MessageSD(content: systemPrompt, role: "system")
            systemMessage.conversation = conversation
        }

        /// construct new message
        let userMessage = MessageSD(content: userPrompt, role: "user", image: image?.render()?.compressImageData())
        userMessage.conversation = conversation

        let assistantMessage = MessageSD(content: "", role: "assistant")
        assistantMessage.conversation = conversation

        conversationState = .loading

        let provider = model.modelProvider ?? .ollama

        Task {
            try await swiftDataService.updateConversation(conversation)
            try await swiftDataService.createMessage(userMessage)
            try await swiftDataService.createMessage(assistantMessage)
            try await reloadConversation(conversation)
            try? await loadConversations()

            switch provider {
            case .ollama:
                await sendViaOllama(model: model, conversation: conversation, image: image)
            case .openai:
                await sendViaOpenAI(model: model, conversation: conversation, image: image)
            }
        }
    }

    // MARK: - Ollama Provider

    private func sendViaOllama(model: LanguageModelSD, conversation: ConversationSD, image: Image?) async {
        var messageHistory = conversation.messages
            .sorted { $0.createdAt < $1.createdAt }
            .map { OKChatRequestData.Message(role: OKChatRequestData.Message.Role(rawValue: $0.role) ?? .assistant, content: $0.content) }

        /// attach selected image to the last Message
        if let image = image?.render() {
            if let lastMessage = messageHistory.popLast() {
                let imagesBase64: [String] = [image.convertImageToBase64String()]
                let messageWithImage = OKChatRequestData.Message(role: lastMessage.role, content: lastMessage.content, images: imagesBase64)
                messageHistory.append(messageWithImage)
            }
        }

        if await OllamaService.shared.ollamaKit.reachable() {
            DispatchQueue.global(qos: .background).async {
                var request = OKChatRequestData(model: model.name, messages: messageHistory)
                request.options = OKCompletionOptions(temperature: 0)

                self.generation = OllamaService.shared.ollamaKit.chat(data: request)
                    .sink(receiveCompletion: { [weak self] completion in
                        switch completion {
                        case .finished:
                            self?.handleComplete()
                        case .failure(let error):
                            self?.handleError(error.localizedDescription)
                        }
                    }, receiveValue: { [weak self] response in
                        self?.handleOllamaReceive(response)
                    })
            }
        } else {
            await MainActor.run {
                self.handleError("Ollama server unreachable")
            }
        }
    }

    // MARK: - OpenAI Provider

    private func sendViaOpenAI(model: LanguageModelSD, conversation: ConversationSD, image: Image?) async {
        let sortedMessages = conversation.messages.sorted { $0.createdAt < $1.createdAt }

        var openAIMessages: [OpenAIChatMessage] = []

        for (index, msg) in sortedMessages.enumerated() {
            let isLastUserMessage = (index == sortedMessages.count - 2) // second to last is the user message
            let hasImage = isLastUserMessage && image != nil && model.supportsImages

            if hasImage, let renderedImage = image?.render() {
                let base64 = renderedImage.convertImageToBase64String()
                let parts: [OpenAIContentPart] = [
                    .textPart(msg.content),
                    .imagePart(base64Data: base64)
                ]
                openAIMessages.append(OpenAIChatMessage(role: msg.role, parts: parts))
            } else {
                // Skip the empty assistant message (last message is placeholder)
                if msg.role == "assistant" && msg.content.isEmpty && index == sortedMessages.count - 1 {
                    continue
                }
                openAIMessages.append(OpenAIChatMessage(role: msg.role, text: msg.content))
            }
        }

        let stream = OpenAIService.shared.streamChat(
            model: model.name,
            messages: openAIMessages,
            temperature: 0.7
        )

        openAITask = Task { [weak self] in
            do {
                for try await content in stream {
                    guard !Task.isCancelled else { break }
                    await self?.handleOpenAIReceive(content)
                }
                await self?.handleComplete()
            } catch {
                if !Task.isCancelled {
                    await self?.handleError(error.localizedDescription)
                }
            }
        }
    }

    // MARK: - Response Handlers

    @MainActor
    private func handleOllamaReceive(_ response: OKChatResponse) {
        if messages.isEmpty { return }

        if let responseContent = response.message?.content {
            currentMessageBuffer = currentMessageBuffer + responseContent

            throttler.throttle { [weak self] in
                guard let self = self else { return }
                let lastIndex = self.messages.count - 1
                self.messages[lastIndex].content.append(currentMessageBuffer)
                currentMessageBuffer = ""
            }
        }
    }

    @MainActor
    private func handleOpenAIReceive(_ content: String) {
        if messages.isEmpty { return }

        currentMessageBuffer = currentMessageBuffer + content

        throttler.throttle { [weak self] in
            guard let self = self else { return }
            let lastIndex = self.messages.count - 1
            self.messages[lastIndex].content.append(currentMessageBuffer)
            currentMessageBuffer = ""
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
        guard let lastMessage = messages.last else { return }
        lastMessage.error = false
        lastMessage.done = true

        Task(priority: .background) {
            try await self.swiftDataService.updateMessage(lastMessage)
        }

        withAnimation {
            conversationState = .completed
        }
    }
}
