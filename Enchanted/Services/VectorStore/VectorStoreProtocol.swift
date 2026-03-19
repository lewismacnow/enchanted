//
//  VectorStoreProtocol.swift
//  Re-Enchanted
//
//  Protocol for vector storage backends used by DejaView.
//  Implementations include in-memory (local), ChromaDB, Qdrant, and pgvector.
//

import Foundation

/// A backend for storing and searching vector embeddings with associated metadata.
protocol VectorStore {
    /// Store an embedding with its identifier and metadata.
    /// - Parameters:
    ///   - id: Unique identifier for the vector entry.
    ///   - embedding: The float vector to store.
    ///   - metadata: Key-value metadata associated with this entry.
    func store(id: String, embedding: [Float], metadata: [String: String]) async throws

    /// Search for the nearest vectors to the query.
    /// - Parameters:
    ///   - query: The query vector.
    ///   - topK: Maximum number of results to return.
    ///   - filter: Optional closure to filter results by id and metadata before ranking.
    /// - Returns: Array of tuples containing id, similarity score, and metadata, sorted by descending score.
    func search(
        query: [Float],
        topK: Int,
        filter: ((String, [String: String]) -> Bool)?
    ) async throws -> [(id: String, score: Float, metadata: [String: String])]

    /// Delete a vector entry by its identifier.
    func delete(id: String) async throws
}
