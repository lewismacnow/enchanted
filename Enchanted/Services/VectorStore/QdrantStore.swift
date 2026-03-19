//
//  QdrantStore.swift
//  Re-Enchanted
//
//  Qdrant REST API client for DejaView vector storage.
//  Connects to a Qdrant instance via its HTTP API (default: localhost:6333).
//

import Foundation

// MARK: - Configuration

struct QdrantConfig {
    /// Base URL of the Qdrant instance (e.g., "http://localhost:6333").
    let baseURL: String

    /// Collection name to use for DejaView embeddings.
    let collectionName: String

    static let defaultConfig = QdrantConfig(
        baseURL: "http://localhost:6333",
        collectionName: "dejaview"
    )
}

// MARK: - Request / Response Types

private struct QdrantUpsertRequest: Codable {
    let points: [QdrantPoint]
}

private struct QdrantPoint: Codable {
    let id: String
    let vector: [Float]
    let payload: [String: String]
}

private struct QdrantSearchRequest: Codable {
    let vector: [Float]
    let limit: Int
    let with_payload: Bool
}

private struct QdrantSearchResponse: Codable {
    let result: [QdrantSearchResult]?
}

private struct QdrantSearchResult: Codable {
    let id: QdrantPointId
    let score: Float
    let payload: [String: String]?
}

/// Qdrant point IDs can be integers or strings.
private enum QdrantPointId: Codable {
    case string(String)
    case int(Int)

    var stringValue: String {
        switch self {
        case .string(let s): return s
        case .int(let i): return String(i)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let s = try? container.decode(String.self) {
            self = .string(s)
        } else if let i = try? container.decode(Int.self) {
            self = .int(i)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "QdrantPointId must be String or Int"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s): try container.encode(s)
        case .int(let i): try container.encode(i)
        }
    }
}

private struct QdrantDeleteRequest: Codable {
    let points: [String]
}

// MARK: - Error

struct QdrantError: Error, LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

// MARK: - Store

/// Qdrant vector store client using the REST API.
class QdrantStore: VectorStore, @unchecked Sendable {

    private let config: QdrantConfig
    private let session: URLSession

    init(config: QdrantConfig = .defaultConfig) {
        self.config = config

        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: sessionConfig)
    }

    func store(id: String, embedding: [Float], metadata: [String: String]) async throws {
        let body = QdrantUpsertRequest(
            points: [QdrantPoint(id: id, vector: embedding, payload: metadata)]
        )

        let path = "/collections/\(config.collectionName)/points"
        try await putRequest(path: path, body: body)
    }

    func search(
        query: [Float],
        topK: Int,
        filter: (@Sendable (String, [String: String]) -> Bool)?
    ) async throws -> [(id: String, score: Float, metadata: [String: String])] {
        let body = QdrantSearchRequest(
            vector: query,
            limit: topK,
            with_payload: true
        )

        let path = "/collections/\(config.collectionName)/points/search"
        let data = try await postRequest(path: path, body: body)

        let response = try JSONDecoder().decode(QdrantSearchResponse.self, from: data)

        guard let results = response.result else { return [] }

        var output: [(id: String, score: Float, metadata: [String: String])] = []
        for result in results {
            let id = result.id.stringValue
            let meta = result.payload ?? [:]

            if let filter = filter, !filter(id, meta) {
                continue
            }

            output.append((id: id, score: result.score, metadata: meta))
        }

        return output
    }

    func delete(id: String) async throws {
        let body = QdrantDeleteRequest(points: [id])
        let path = "/collections/\(config.collectionName)/points/delete"
        try await postRequest(path: path, body: body)
    }

    // MARK: - HTTP Helpers

    @discardableResult
    private func putRequest<T: Encodable>(path: String, body: T) async throws -> Data {
        return try await httpRequest(method: "PUT", path: path, body: body)
    }

    @discardableResult
    private func postRequest<T: Encodable>(path: String, body: T) async throws -> Data {
        return try await httpRequest(method: "POST", path: path, body: body)
    }

    private func httpRequest<T: Encodable>(method: String, path: String, body: T) async throws -> Data {
        let baseURL = config.baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let urlString = "\(baseURL)\(path)"

        guard let url = URL(string: urlString) else {
            throw QdrantError(message: "Invalid URL: \(urlString)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw QdrantError(message: "Invalid response from Qdrant")
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw QdrantError(message: "Qdrant HTTP \(httpResponse.statusCode): \(errorBody)")
        }

        return data
    }
}
