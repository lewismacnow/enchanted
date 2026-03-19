//
//  ScreenCaptureSD.swift
//  Re-Enchanted
//
//  SwiftData model for DejaView screen captures.
//  Stores screenshot metadata, extracted OCR text, and embedding vectors.
//

import Foundation
import SwiftData

@Model
final class ScreenCaptureSD: Identifiable {
    @Attribute(.unique) var id: UUID = UUID()
    var timestamp: Date
    var imagePath: String
    var extractedText: String = ""
    var embeddingData: Data?

    /// Deserializes embeddingData into a Float array for vector search.
    @Transient var embedding: [Float]? {
        guard let data = embeddingData else { return nil }
        return data.withUnsafeBytes { buffer in
            guard let pointer = buffer.baseAddress?.assumingMemoryBound(to: Float.self) else {
                return nil
            }
            return Array(UnsafeBufferPointer(start: pointer, count: data.count / MemoryLayout<Float>.stride))
        }
    }

    init(timestamp: Date, imagePath: String, extractedText: String = "", embeddingData: Data? = nil) {
        self.timestamp = timestamp
        self.imagePath = imagePath
        self.extractedText = extractedText
        self.embeddingData = embeddingData
    }

    /// Convenience: serialize a Float array into Data for storage.
    static func serializeEmbedding(_ embedding: [Float]) -> Data {
        return embedding.withUnsafeBufferPointer { buffer in
            Data(buffer: buffer)
        }
    }

    nonisolated(unsafe) static let sample = ScreenCaptureSD(
        timestamp: Date(),
        imagePath: "~/Library/Application Support/Re-Enchanted/DejaView/sample.jpg",
        extractedText: "Sample OCR text from a screenshot",
        embeddingData: nil
    )
}
