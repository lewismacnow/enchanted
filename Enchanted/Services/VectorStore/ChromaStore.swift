//
//  ChromaStore.swift
//  Re-Enchanted
//
//  ChromaDB REST API client for DejaView vector storage.
//  Connects to a ChromaDB instance via its HTTP API (default: localhost:8000).
//

import Foundation

// MARK: - Configuration

struct ChromaConfig {
    /// Base URL of the ChromaDB instance (e.g., "http://localhost:8000").
    let baseURL: String

    /// Collection name to use for DejaView embeddings.
    let collectionName: String

    static let defaultConfig = ChromaConfig(
        baseURL: "http://localhost:8000",
        collectionName: "dejaview"
    )
}

// MARK: - Request / Response Types

private struct ChromaAddRequest: Codable {
    let ids: [String]
    let embeddings: [[Float]]
    let metadatas: [[String: String]]
}

private struct ChromaQueryRequest: Codable {
    let query_embeddings: [[Float]]
    let n_results: Int
}

private struct ChromaQueryResponse: Codable {
    let ids: [[String]]?
    let distances: [[Float]]?
    let metadatas: [[[String: String]]]?
}

private struct ChromaDeleteRequest: Codable {
    let ids: [String]
}

// MARK: - Error

struct ChromaError: Error, LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

// MARK: - Store

/// ChromaDB vector store client using the REST API.
class ChromaStore: VectorStore, @unchecked Sendable {

    private let config: ChromaConfig
    private let session: URLSession

    init(config: ChromaConfig = .defaultConfig) {
        self.config = config

        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: sessionConfig)
    }

    func store(id: String, embedding: [Float], metadata: [String: String]) async throws {
        let body = ChromaAddRequest(
            ids: [id],
            embeddings: [embedding],
            metadatas: [metadata]
        )

        let path = "/api/v1/collections/\(config.collectionName)/add"
        try await postRequest(path: path, body: body)
    }

    func search(
        query: [Float],
        topK: Int,
        filter: ((String, [String: String]) -> Bool)?
    ) async throws -> [(id: String, score: Float, metadata: [String: String])] {
        let body = ChromaQueryRequest(
            query_embeddings: [query],
            n_results: topK
        )

        let path = "/api/v1/collections/\(config.collectionName)/query"
        let data = try await postRequest(path: path, body: body)

        let response = try JSONDecoder().decode(ChromaQueryResponse.self, from: data)

        guard let ids = response.ids?.first,
              let distances = response.distances?.first else {
            return []
        }

        let metadatas = response.metadatas?.first ?? Array(repeating: [:], count: ids.count)

        var results: [(id: String, score: Float, metadata: [String: String])] = []
        for i in 0..<ids.count {
            let id = ids[i]
            let meta = i < metadatas.count ? metadatas[i] : [:]

            // ChromaDB returns distances (lower = more similar).
            // Convert to a similarity score: score = 1 / (1 + distance).
            let distance = i < distances.count ? distances[i] : Float.greatestFiniteMagnitude
            let score = 1.0 / (1.0 + distance)

            if let filter = filter, !filter(id, meta) {
                continue
            }

            results.append((id: id, score: score, metadata: meta))
        }

        results.sort { $0.score > $1.score }
        return results
    }

    func delete(id: String) async throws {
        let body = ChromaDeleteRequest(ids: [id])
        let path = "/api/v1/collections/\(config.collectionName)/delete"
        try await postRequest(path: path, body: body)
    }

    // MARK: - HTTP Helpers

    @discardableResult
    private func postRequest<T: Encodable>(path: String, body: T) async throws -> Data {
        let baseURL = config.baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let urlString = "\(baseURL)\(path)"

        guard let url = URL(string: urlString) else {
            throw ChromaError(message: "Invalid URL: \(urlString)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ChromaError(message: "Invalid response from ChromaDB")
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ChromaError(message: "ChromaDB HTTP \(httpResponse.statusCode): \(errorBody)")
        }

        return data
    }
}
