//
//  PromptPanelVM.swift
//  Re-Enchanted
//
//  Originally created by Augustinas Malinauskas on 29/02/2024.
//

#if os(macOS)
import SwiftUI
import OllamaKit
import Combine

@Observable
final class CompletionsPanelVM {
    var selectedText: String?
    var onReceiveText: (String) -> ()
    var messageResponse: String = ""
    var isReady = false
    let sentenceQueue = AsyncQueue<String>()
    private var generation: AnyCancellable?
    private var currentMessageBuffer: String = ""

    init(onReceiveText: @escaping (String) -> Void = { _ in }) {
        self.onReceiveText = onReceiveText
    }

    static func constructPrompt(completion: CompletionInstructionSD, selectedText: String) -> String {
        var prompt = completion.instruction

        if prompt.contains("{{text}}") {
            prompt.replace("{{text}}", with: selectedText)
        } else {
            prompt += " " + selectedText
        }

        return prompt
    }

    /// Capture a screenshot of the current screen for vision-capable models (macOS only).
    #if os(macOS)
    @MainActor
    func captureScreenForVision() -> Image? {
        guard let screen = NSScreen.main,
              let cgImage = CGWindowListCreateImage(
                screen.frame,
                .optionOnScreenOnly,
                kCGNullWindowID,
                [.bestResolution]
              ) else {
            return nil
        }
        let nsImage = NSImage(cgImage: cgImage, size: screen.frame.size)
        return Image(nsImage: nsImage)
    }
    #endif

    @MainActor
    func sendPrompt(completion: CompletionInstructionSD, model: LanguageModelSD) {
        guard let selectedText = selectedText, !isReady else { return }
        let prompt = CompletionsPanelVM.constructPrompt(completion: completion, selectedText: selectedText)

        // Build messages with optional image for vision-capable models
        var messages: [OKChatRequestData.Message] = []
        var imagesBase64: [String] = []

        #if os(macOS)
        if model.supportsImages, let screenImage = captureScreenForVision(),
           let rendered = screenImage.render() {
            let base64 = rendered.convertImageToBase64String()
            if !base64.isEmpty {
                imagesBase64 = [base64]
            }
        }
        #endif

        if imagesBase64.isEmpty {
            messages = [.init(role: .user, content: prompt)]
        } else {
            messages = [.init(role: .user, content: prompt, images: imagesBase64)]
        }

        var request = OKChatRequestData(model: model.name, messages: messages)
        request.options = OKCompletionOptions(temperature: completion.modelTemperature ?? 0.8)
        currentMessageBuffer = ""
        messageResponse = ""

        Task {
            if await OllamaService.shared.ollamaKit.reachable() {
                generation = OllamaService.shared.ollamaKit.chat(data: request)
                    .sink(receiveCompletion: { [weak self] completion in
                        switch completion {
                        case .finished:
                            self?.handleComplete()
                        case .failure(let error):
                            self?.handleError(error.localizedDescription)
                        }
                    }, receiveValue: { [weak self] response in
                        self?.handleReceive(response)
                    })
            } else {
                self.handleError("Server unreachable")
            }
        }
    }

    @MainActor
    private func handleReceive(_ response: OKChatResponse) {
        Task {
            if let responseContent = response.message?.content {
                await sentenceQueue.enqueue(responseContent)
                self.messageResponse = self.messageResponse + responseContent
            }
        }
    }

    @MainActor
    private func handleError(_ errorMessage: String) {
        print("Completion error: \(errorMessage)")
    }

    @MainActor
    private func handleComplete() {
        print("Completion response: \(self.messageResponse)")
    }

    @MainActor
    func cancel() {
        generation?.cancel()
    }
}
#endif
