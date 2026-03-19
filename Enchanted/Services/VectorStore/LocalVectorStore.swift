//
//  LocalVectorStore.swift
//  Re-Enchanted
//
//  Persistent on-disk vector store using brute-force cosine similarity search.
//  Data is stored as a JSON file in Application Support for durability across restarts.
//

import Foundation

/// An entry stored in the local vector store.
private struct VectorEntry: Codable {
    let embedding: [Float]
    let metadata: [String: String]
}

/// On-disk brute-force vector store with cosine similarity search.
actor LocalVectorStore: VectorStore {

    private var entries: [String: VectorEntry] = [:]
    private let storageURL: URL
    private var isDirty = false

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Re-Enchanted", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        storageURL = dir.appendingPathComponent("dejaview_vectors.json")

        // Load from disk
        if let data = try? Data(contentsOf: storageURL),
           let loaded = try? JSONDecoder().decode([String: VectorEntry].self, from: data) {
            entries = loaded
        }
    }

    func store(id: String, embedding: [Float], metadata: [String: String]) async throws {
        entries[id] = VectorEntry(embedding: embedding, metadata: metadata)
        try saveToDisk()
    }

    func search(
        query: [Float],
        topK: Int,
        filter: (@Sendable (String, [String: String]) -> Bool)?
    ) async throws -> [(id: String, score: Float, metadata: [String: String])] {
        var results: [(id: String, score: Float, metadata: [String: String])] = []

        for (id, entry) in entries {
            if let filter = filter, !filter(id, entry.metadata) {
                continue
            }

            let score = cosineSimilarity(query, entry.embedding)
            results.append((id: id, score: score, metadata: entry.metadata))
        }

        results.sort { $0.score > $1.score }
        return Array(results.prefix(topK))
    }

    func delete(id: String) async throws {
        entries.removeValue(forKey: id)
        try saveToDisk()
    }

    // MARK: - Persistence

    private func saveToDisk() throws {
        let data = try JSONEncoder().encode(entries)
        try data.write(to: storageURL, options: .atomic)
    }

    // MARK: - Cosine Similarity

    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0.0 }

        var dot: Float = 0.0
        var normA: Float = 0.0
        var normB: Float = 0.0

        for i in 0..<a.count {
            dot += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }

        guard normA > 0, normB > 0 else { return 0.0 }
        let denominator = sqrtf(normA) * sqrtf(normB)
        guard denominator.isFinite, denominator > 0 else { return 0.0 }

        let result = dot / denominator
        return result.isFinite ? result : 0.0
    }
}
