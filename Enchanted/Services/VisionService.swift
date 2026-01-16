//
//  VisionService.swift
//  Enchanted
//
//  Created by OpenHands AI on 2024.
//

import Foundation
import SwiftUI
import OpenAI

class VisionService: @unchecked Sendable {
    static let shared = VisionService()
    
    private init() {}
    
    /// Describe an image using a vision model for non-vision models
    func describeImage(_ image: Image, model: LanguageModelSD) async throws -> String {
        // Convert image to base64
        guard let imageData = image.render()?.convertImageToBase64String() else {
            throw VisionError(description: "Failed to convert image to base64")
        }
        
        // Use OpenAI-compatible vision model to describe the image
        let imageContent = OpenAI.Chat.ChatCompletionMessage.Content.image(
            OpenAI.Chat.ChatCompletionMessage.Content.Image(
                url: "data:image/jpeg;base64,\(imageData)",
                detail: .auto
            )
        )
        
        let userMessage = OpenAI.Chat.ChatCompletionMessage(
            role: .user,
            content: [
                .text("Describe this image in detail. What can you see?"),
                imageContent
            ]
        )
        
        let messages = [userMessage]
        
        // Use the OpenAI service to get description
        let stream = try await OpenAIService.shared.chatCompletion(
            model: model.name,
            messages: messages,
            temperature: 0.5,
            stream: true
        )
        
        var description = ""
        for try await chunk in stream {
            if let content = chunk.choices.first?.delta.content {
                description += content
            }
        }
        
        return description
    }
}

// Custom error type for vision service
struct VisionError: Error, LocalizedError {
    let description: String
    
    var errorDescription: String? {
        return description
    }
}