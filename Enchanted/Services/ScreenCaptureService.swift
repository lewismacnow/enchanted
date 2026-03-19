//
//  ScreenCaptureService.swift
//  Re-Enchanted
//
//  macOS-only service for DejaView screen recall.
//  Captures screenshots, runs OCR via Apple Vision, generates embeddings,
//  and saves images to disk for later retrieval.
//

#if os(macOS)
import Foundation
import AppKit
import CoreGraphics
import Vision

// MARK: - Error

struct ScreenCaptureError: Error, LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

// MARK: - Service

class ScreenCaptureService: @unchecked Sendable {
    static let shared = ScreenCaptureService()

    private let embeddingService: EmbeddingService
    private let fileManager = FileManager.default

    /// Directory where DejaView screenshots are stored.
    private var storageDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport
            .appendingPathComponent("Re-Enchanted", isDirectory: true)
            .appendingPathComponent("DejaView", isDirectory: true)
    }

    private var captureTimer: Timer?
    private var isCapturing = false

    private init() {
        self.embeddingService = EmbeddingService.shared
        ensureStorageDirectoryExists()
    }

    // MARK: - Storage

    private func ensureStorageDirectoryExists() {
        if !fileManager.fileExists(atPath: storageDirectory.path) {
            try? fileManager.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
        }
    }

    // MARK: - Screenshot Capture

    /// Capture a screenshot of each display separately using NSScreen.screens.
    func captureScreenshots() -> [CGImage] {
        var images: [CGImage] = []
        for screen in NSScreen.screens {
            let frame = screen.frame
            // NSScreen uses bottom-left origin; CGWindowListCreateImage uses top-left.
            // CGWindowListCreateImage with a specific rect captures that region of the global display space.
            let cgRect = CGRect(
                x: frame.origin.x,
                y: frame.origin.y,
                width: frame.width,
                height: frame.height
            )
            if let image = CGWindowListCreateImage(
                cgRect,
                .optionOnScreenOnly,
                kCGNullWindowID,
                [.bestResolution]
            ) {
                images.append(image)
            }
        }
        return images
    }

    /// Save a CGImage to disk as JPEG and return the file path.
    func saveScreenshot(_ image: CGImage) throws -> String {
        ensureStorageDirectoryExists()

        let filename = "dejaview_\(Int(Date().timeIntervalSince1970 * 1000))_\(UUID().uuidString.prefix(6)).jpg"
        let fileURL = storageDirectory.appendingPathComponent(filename)

        let bitmapRep = NSBitmapImageRep(cgImage: image)
        guard let jpegData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) else {
            throw ScreenCaptureError(message: "Failed to convert screenshot to JPEG")
        }

        try jpegData.write(to: fileURL)
        return fileURL.path
    }

    // MARK: - OCR via Apple Vision

    /// Extract text from a CGImage using VNRecognizeTextRequest.
    func extractText(from image: CGImage) throws -> String {
        var recognizedText = ""
        var recognitionError: Error?

        let request = VNRecognizeTextRequest { request, error in
            if let error = error {
                recognitionError = error
                return
            }

            guard let observations = request.results as? [VNRecognizedTextObservation] else { return }

            let lines = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }
            recognizedText = lines.joined(separator: "\n")
        }

        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])

        if let error = recognitionError {
            throw ScreenCaptureError(message: "OCR failed: \(error.localizedDescription)")
        }

        return recognizedText
    }

    // MARK: - Vision Model Description

    /// Describe a screenshot using an OpenAI-compatible vision model.
    /// Returns empty string if no vision model is configured.
    func describeWithVision(screenshot: CGImage) async -> String {
        let visionModel = UserDefaults.standard.string(forKey: "dejaViewVisionModel") ?? ""
        guard !visionModel.isEmpty else { return "" }

        // Convert CGImage to JPEG base64
        let bitmapRep = NSBitmapImageRep(cgImage: screenshot)
        guard let jpegData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.7]) else {
            return ""
        }
        let base64String = jpegData.base64EncodedString()

        let systemMessage = OpenAIChatMessage(role: "system", text: "Describe what you see on this screen in detail. Focus on the application content, text, and visual elements.")
        let userMessage = OpenAIChatMessage(role: "user", parts: [
            .textPart("Describe this screenshot:"),
            .imagePart(base64Data: base64String, mimeType: "image/jpeg")
        ])

        var fullResponse = ""
        let stream = OpenAIService.shared.streamChat(
            model: visionModel,
            messages: [systemMessage, userMessage],
            temperature: 0.3
        )

        do {
            for try await chunk in stream {
                fullResponse += chunk
            }
        } catch {
            print("Vision description failed: \(error)")
            return ""
        }

        return fullResponse
    }

    // MARK: - Full Pipeline

    /// Capture all screens, run OCR, optionally get vision description, generate embeddings.
    /// Returns one result per screen.
    func captureAndProcess() async throws -> [(imagePath: String, extractedText: String, visionDescription: String, embedding: [Float])] {
        let screenshots = captureScreenshots()
        guard !screenshots.isEmpty else {
            throw ScreenCaptureError(message: "Failed to capture any screenshots")
        }

        var results: [(imagePath: String, extractedText: String, visionDescription: String, embedding: [Float])] = []

        for screenshot in screenshots {
            let imagePath = try saveScreenshot(screenshot)
            let extractedText = try extractText(from: screenshot)
            let visionDescription = await describeWithVision(screenshot: screenshot)

            // Combine OCR text and vision description for embedding
            var textToEmbed = extractedText
            if !visionDescription.isEmpty {
                textToEmbed = textToEmbed.isEmpty
                    ? visionDescription
                    : "\(textToEmbed)\n\n[Vision Description]\n\(visionDescription)"
            }

            let embedding: [Float]
            if textToEmbed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                embedding = try await embeddingService.embed(text: "[screenshot with no detected text]")
            } else {
                embedding = try await embeddingService.embed(text: textToEmbed)
            }

            results.append((
                imagePath: imagePath,
                extractedText: extractedText,
                visionDescription: visionDescription,
                embedding: embedding
            ))
        }

        return results
    }

    // MARK: - Timer-Based Capture

    /// Start periodic screen capture at the given interval (in seconds).
    /// The `onCapture` callback is invoked with the result of each capture.
    @MainActor
    func startCapturing(
        interval: TimeInterval,
        onCapture: @escaping (Result<[(imagePath: String, extractedText: String, visionDescription: String, embedding: [Float])], Error>) -> Void
    ) {
        guard !isCapturing else { return }
        isCapturing = true

        captureTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task {
                do {
                    let result = try await self.captureAndProcess()
                    onCapture(.success(result))
                } catch {
                    onCapture(.failure(error))
                }
            }
        }
    }

    /// Stop periodic screen capture.
    @MainActor
    func stopCapturing() {
        captureTimer?.invalidate()
        captureTimer = nil
        isCapturing = false
    }
}

#endif
