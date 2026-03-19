//
//  PgVectorStore.swift
//  Re-Enchanted
//
//  PostgreSQL + pgvector backend for DejaView vector storage.
//
//  IMPORTANT: This store requires a REST API gateway in front of PostgreSQL
//  (e.g., PostgREST, pg_graphql, or a custom HTTP server) that accepts JSON
//  payloads and executes SQL against a pgvector-enabled database.
//
//  Expected table schema:
//    CREATE EXTENSION IF NOT EXISTS vector;
//    CREATE TABLE IF NOT EXISTS embeddings (
//        id TEXT PRIMARY KEY,
//        embedding vector(768),
//        metadata JSONB DEFAULT '{}'
//    );
//
//  The REST gateway should expose:
//    POST /rpc/store_embedding   - body: {id, embedding, metadata}
//    POST /rpc/search_embeddings - body: {query_embedding, top_k}
//    POST /rpc/delete_embedding  - body: {id}
//

import Foundation

// MARK: - Configuration

struct PgVectorConfig {
    /// Base URL of the REST API gateway (e.g., "http://localhost:3000").
    let baseURL: String
    let username: String
    let password: String
    let database: String

    /// Default configuration pointing to a local PostgREST instance.
    static let defaultConfig = PgVectorConfig(
        baseURL: "http://localhost:3000",
        username: "postgres",
        password: "",
        database: "re_enchanted"
    )
}

// MARK: - Request / Response Types

private struct PgStoreRequest: Codable {
    let id: String
    let embedding: [Float]
    let metadata: [String: String]
}

private struct PgSearchRequest: Codable {
    let query_embedding: [Float]
    let top_k: Int
}

private struct PgSearchResult: Codable {
    let id: String
    let score: Float
    let metadata: [String: String]
}

private struct PgDeleteRequest: Codable {
    let id: String
}

// MARK: - Error

struct PgVectorError: Error, LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

// MARK: - Store

/// PostgreSQL + pgvector vector store accessed via a REST API gateway.
///
/// NOTE: This does NOT connect directly to PostgreSQL. It requires a REST
/// endpoint (PostgREST, custom server, etc.) that translates HTTP requests
/// into SQL queries against a pgvector-enabled database.
class PgVectorStore: VectorStore, @unchecked Sendable {

    private let config: PgVectorConfig
    private let session: URLSession

    init(config: PgVectorConfig = .defaultConfig) {
        self.config = config

        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: sessionConfig)
    }

    func store(id: String, embedding: [Float], metadata: [String: String]) async throws {
        let body = PgStoreRequest(id: id, embedding: embedding, metadata: metadata)
        let _ = try await postRequest(path: "/rpc/store_embedding", body: body)
    }

    func search(
        query: [Float],
        topK: Int,
        filter: ((String, [String: String]) -> Bool)?
    ) async throws -> [(id: String, score: Float, metadata: [String: String])] {
        let body = PgSearchRequest(query_embedding: query, top_k: topK)
        let data = try await postRequest(path: "/rpc/search_embeddings", body: body)

        let results = try JSONDecoder().decode([PgSearchResult].self, from: data)

        // Apply client-side filter if provided
        let filtered: [PgSearchResult]
        if let filter = filter {
            filtered = results.filter { filter($0.id, $0.metadata) }
        } else {
            filtered = results
        }

        return filtered.map { (id: $0.id, score: $0.score, metadata: $0.metadata) }
    }

    func delete(id: String) async throws {
        let body = PgDeleteRequest(id: id)
        let _ = try await postRequest(path: "/rpc/delete_embedding", body: body)
    }

    // MARK: - HTTP Helpers

    @discardableResult
    private func postRequest<T: Encodable>(path: String, body: T) async throws -> Data {
        let baseURL = config.baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let urlString = "\(baseURL)\(path)"

        guard let url = URL(string: urlString) else {
            throw PgVectorError(message: "Invalid URL: \(urlString)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Basic auth for PostgREST
        if !config.username.isEmpty {
            let credentials = "\(config.username):\(config.password)"
            if let credData = credentials.data(using: .utf8) {
                request.setValue("Basic \(credData.base64EncodedString())", forHTTPHeaderField: "Authorization")
            }
        }

        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PgVectorError(message: "Invalid response from pgvector REST gateway")
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw PgVectorError(message: "pgvector HTTP \(httpResponse.statusCode): \(errorBody)")
        }

        return data
    }
}
