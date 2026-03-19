//
//  LocalVectorStore.swift
//  Re-Enchanted
//
//  In-memory vector store using brute-force cosine similarity search.
//  Thread-safe via Swift actor isolation. Suitable for moderate dataset sizes.
//

import Foundation

/// An entry stored in the local vector store.
private struct VectorEntry {
    let embedding: [Float]
    let metadata: [String: String]
}

/// In-memory brute-force vector store with cosine similarity search.
actor LocalVectorStore: VectorStore {

    private var entries: [String: VectorEntry] = [:]

    init() {}

    func store(id: String, embedding: [Float], metadata: [String: String]) async throws {
        entries[id] = VectorEntry(embedding: embedding, metadata: metadata)
    }

    func search(
        query: [Float],
        topK: Int,
        filter: ((String, [String: String]) -> Bool)?
    ) async throws -> [(id: String, score: Float, metadata: [String: String])] {
        var results: [(id: String, score: Float, metadata: [String: String])] = []

        for (id, entry) in entries {
            // Apply optional filter
            if let filter = filter, !filter(id, entry.metadata) {
                continue
            }

            let score = cosineSimilarity(query, entry.embedding)
            results.append((id: id, score: score, metadata: entry.metadata))
        }

        // Sort by score descending, take top K
        results.sort { $0.score > $1.score }
        return Array(results.prefix(topK))
    }

    func delete(id: String) async throws {
        entries.removeValue(forKey: id)
    }

    // MARK: - Cosine Similarity

    /// Compute cosine similarity: dot(a, b) / (norm(a) * norm(b)).
    /// Returns 0.0 if either vector has zero magnitude.
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

        let denominator = sqrtf(normA) * sqrtf(normB)
        guard denominator > 0 else { return 0.0 }

        return dot / denominator
    }
}
