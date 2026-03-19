//
//  DejaViewStore.swift
//  Re-Enchanted
//
//  Manages DejaView screen capture state, vector search, and persistence.
//

import Foundation
import SwiftData

@Observable
final class DejaViewStore: @unchecked Sendable {
    static let shared = DejaViewStore(swiftDataService: SwiftDataService.shared)

    private let swiftDataService: SwiftDataService
    private var vectorStore: any VectorStore

    #if os(macOS)
    private var captureTimer: Timer?
    #endif

    @MainActor var captures: [ScreenCaptureSD] = []
    @MainActor var searchResults: [(capture: ScreenCaptureSD, score: Float)] = []
    @MainActor var isCapturing: Bool = false

    @MainActor var captureInterval: TimeInterval = {
        let saved = UserDefaults.standard.double(forKey: "dejaViewInterval")
        return saved > 0 ? saved : 30
    }() {
        didSet {
            UserDefaults.standard.set(captureInterval, forKey: "dejaViewInterval")
        }
    }

    @MainActor var vectorStoreType: String = {
        UserDefaults.standard.string(forKey: "dejaViewStoreType") ?? "local"
    }() {
        didSet {
            UserDefaults.standard.set(vectorStoreType, forKey: "dejaViewStoreType")
            configureVectorStore()
        }
    }

    init(swiftDataService: SwiftDataService) {
        self.swiftDataService = swiftDataService
        self.vectorStore = LocalVectorStore()
    }

    // MARK: - Load Captures

    func loadCaptures() async {
        do {
            nonisolated(unsafe) let fetched = try await swiftDataService.fetchScreenCaptures()
            await MainActor.run {
                self.captures = fetched
            }
        } catch {
            print("Failed to load captures: \(error)")
        }
    }

    // MARK: - Capture Control (macOS only)

    #if os(macOS)
    @MainActor
    func startCapturing() {
        guard !isCapturing else { return }
        isCapturing = true

        let interval = captureInterval
        captureTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { await self.performCapture() }
        }
    }

    @MainActor
    func stopCapturing() {
        captureTimer?.invalidate()
        captureTimer = nil
        isCapturing = false
    }

    private func performCapture() async {
        do {
            let result = try await ScreenCaptureService.shared.captureAndProcess()
            let capture = ScreenCaptureSD(
                timestamp: Date(),
                imagePath: result.imagePath,
                extractedText: result.extractedText,
                embeddingData: ScreenCaptureSD.serializeEmbedding(result.embedding)
            )

            try await swiftDataService.createScreenCapture(capture)

            if !result.embedding.isEmpty {
                try await vectorStore.store(
                    id: capture.id.uuidString,
                    embedding: result.embedding,
                    metadata: [
                        "timestamp": ISO8601DateFormatter().string(from: capture.timestamp),
                        "imagePath": capture.imagePath
                    ]
                )
            }

            await loadCaptures()
        } catch {
            print("Failed to perform capture: \(error)")
        }
    }
    #endif

    // MARK: - Search

    func search(query: String, timeFilter: String? = nil) async {
        do {
            let queryEmbedding = try await EmbeddingService.shared.embed(text: query)
            let vectorResults = try await vectorStore.search(query: queryEmbedding, topK: 20, filter: nil)

            nonisolated(unsafe) let allCaptures = try await swiftDataService.fetchScreenCaptures()
            let captureMap = Dictionary(uniqueKeysWithValues: allCaptures.map { ($0.id.uuidString, $0) })

            var matched: [(capture: ScreenCaptureSD, score: Float)] = vectorResults.compactMap { result in
                guard let capture = captureMap[result.id] else { return nil }
                return (capture: capture, score: result.score)
            }

            // Apply time filter
            if let timeFilter, !timeFilter.isEmpty,
               let range = DateParsingService.parseTimeReference(timeFilter) {
                matched = matched.filter { item in
                    range.contains(item.capture.timestamp)
                }
            }

            // Fallback: text-based search
            if matched.isEmpty {
                var textMatched = allCaptures
                    .filter { $0.extractedText.localizedCaseInsensitiveContains(query) }
                    .map { (capture: $0, score: Float(0.5)) }

                if let timeFilter, !timeFilter.isEmpty,
                   let range = DateParsingService.parseTimeReference(timeFilter) {
                    textMatched = textMatched.filter { range.contains($0.capture.timestamp) }
                }

                await MainActor.run { self.searchResults = textMatched }
                return
            }

            await MainActor.run { self.searchResults = matched }
        } catch {
            print("Failed to search: \(error)")
        }
    }

    // MARK: - Delete

    func deleteCapture(_ capture: ScreenCaptureSD) async {
        do {
            try await vectorStore.delete(id: capture.id.uuidString)
            try await swiftDataService.deleteScreenCapture(capture)
            await loadCaptures()
            await MainActor.run {
                self.searchResults.removeAll { $0.capture.id == capture.id }
            }
        } catch {
            print("Failed to delete capture: \(error)")
        }
    }

    // MARK: - Vector Store Configuration

    func configureVectorStore() {
        let type: String
        #if swift(>=5.10)
        type = MainActor.assumeIsolated { self.vectorStoreType }
        #else
        type = "local"
        #endif

        switch type {
        case "pgvector":
            let url = UserDefaults.standard.string(forKey: "dejaViewPgvectorURL") ?? "http://localhost:3000"
            vectorStore = PgVectorStore(config: PgVectorConfig(
                baseURL: url, username: "postgres", password: "", database: "reenchanted"
            ))
        case "chromadb":
            let url = UserDefaults.standard.string(forKey: "dejaViewChromaURL") ?? "http://localhost:8000"
            vectorStore = ChromaStore(config: ChromaConfig(baseURL: url, collectionName: "dejaview"))
        case "qdrant":
            let url = UserDefaults.standard.string(forKey: "dejaViewQdrantURL") ?? "http://localhost:6333"
            vectorStore = QdrantStore(config: QdrantConfig(baseURL: url, collectionName: "dejaview"))
        default:
            vectorStore = LocalVectorStore()
        }
    }
}
