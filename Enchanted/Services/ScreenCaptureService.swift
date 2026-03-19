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

    /// Capture a screenshot of all on-screen content using CGWindowListCreateImage.
    func captureScreenshot() throws -> CGImage {
        guard let image = CGWindowListCreateImage(
            .null,
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.bestResolution]
        ) else {
            throw ScreenCaptureError(message: "Failed to capture screenshot via CGWindowListCreateImage")
        }
        return image
    }

    /// Save a CGImage to disk as JPEG and return the file path.
    func saveScreenshot(_ image: CGImage) throws -> String {
        ensureStorageDirectoryExists()

        let filename = "dejaview_\(Int(Date().timeIntervalSince1970 * 1000)).jpg"
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

    // MARK: - Full Pipeline

    /// Capture screenshot, run OCR, generate embedding, and return all results.
    func captureAndProcess() async throws -> (imagePath: String, extractedText: String, embedding: [Float]) {
        let screenshot = try captureScreenshot()
        let imagePath = try saveScreenshot(screenshot)
        let extractedText = try extractText(from: screenshot)

        let embedding: [Float]
        if extractedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // No text found; use a placeholder so we still have an embedding
            embedding = try await embeddingService.embed(text: "[screenshot with no detected text]")
        } else {
            embedding = try await embeddingService.embed(text: extractedText)
        }

        return (imagePath: imagePath, extractedText: extractedText, embedding: embedding)
    }

    // MARK: - Timer-Based Capture

    /// Start periodic screen capture at the given interval (in seconds).
    /// The `onCapture` callback is invoked with the result of each capture.
    @MainActor
    func startCapturing(
        interval: TimeInterval,
        onCapture: @escaping (Result<(imagePath: String, extractedText: String, embedding: [Float]), Error>) -> Void
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
