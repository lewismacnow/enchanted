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

    @MainActor var retentionDays: Int = {
        let saved = UserDefaults.standard.integer(forKey: "dejaViewRetentionDays")
        // 0 means "forever"; if never set, default to 30
        return saved == 0 && UserDefaults.standard.object(forKey: "dejaViewRetentionDays") == nil ? 30 : saved
    }() {
        didSet {
            UserDefaults.standard.set(retentionDays, forKey: "dejaViewRetentionDays")
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

    // MARK: - Purge Old Captures

    /// Delete captures older than the configured retention period.
    /// A retentionDays value of 0 means "keep forever" and skips purging.
    func purgeOldCaptures() async {
        let days: Int = await MainActor.run { self.retentionDays }
        guard days > 0 else { return }

        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()

        do {
            nonisolated(unsafe) let allCaptures = try await swiftDataService.fetchScreenCaptures()
            let expired = allCaptures.filter { $0.timestamp < cutoff }

            for capture in expired {
                // Remove screenshot file from disk
                let filePath = capture.imagePath
                if FileManager.default.fileExists(atPath: filePath) {
                    try? FileManager.default.removeItem(atPath: filePath)
                }

                // Remove from vector store
                try? await vectorStore.delete(id: capture.id.uuidString)

                // Remove from SwiftData
                try? await swiftDataService.deleteScreenCapture(capture)
            }

            if !expired.isEmpty {
                print("Purged \(expired.count) captures older than \(days) days")
            }
        } catch {
            print("Failed to purge old captures: \(error)")
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
        // Purge old captures once per capture cycle
        await purgeOldCaptures()

        do {
            let results = try await ScreenCaptureService.shared.captureAndProcess()

            for result in results {
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
                            "imagePath": capture.imagePath,
                            "visionDescription": result.visionDescription
                        ]
                    )
                }
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

                nonisolated(unsafe) let finalTextResults = textMatched
                await MainActor.run { self.searchResults = finalTextResults }
                return
            }

            nonisolated(unsafe) let finalResults = matched
            await MainActor.run { self.searchResults = finalResults }
        } catch {
            print("Failed to search: \(error)")
        }
    }

    // MARK: - Delete

    func deleteCapture(_ capture: ScreenCaptureSD) async {
        let captureId = capture.id
        do {
            try await vectorStore.delete(id: captureId.uuidString)
            try await swiftDataService.deleteScreenCapture(capture)
            await loadCaptures()
            await MainActor.run {
                self.searchResults.removeAll { $0.capture.id == captureId }
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
