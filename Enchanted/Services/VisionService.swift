//
//  VisionService.swift
//  Re-Enchanted
//
//  Image description service using OpenAI-compatible vision API.
//

import Foundation
import SwiftUI

class VisionService: @unchecked Sendable {
    static let shared = VisionService()

    private init() {}

    /// Describe an image using a vision-capable model via the OpenAI-compatible API.
    func describeImage(_ image: Image, model: LanguageModelSD) async throws -> String {
        guard let imageData = image.render()?.convertImageToBase64String() else {
            throw VisionError(description: "Failed to convert image to base64")
        }

        let messages: [OpenAIChatMessage] = [
            OpenAIChatMessage(role: "user", parts: [
                .textPart("Describe this image in detail. What can you see?"),
                .imagePart(base64Data: imageData)
            ])
        ]

        var description = ""
        let stream = OpenAIService.shared.streamChat(
            model: model.name,
            messages: messages,
            temperature: 0.5
        )

        for try await chunk in stream {
            description += chunk
        }

        return description
    }
}

struct VisionError: Error, LocalizedError {
    let description: String
    var errorDescription: String? { description }
}
