//
//  MCPClient.swift
//  Re-Enchanted
//
//  JSON-RPC 2.0 client that communicates with MCP servers via stdio.
//  macOS only — MCP servers are launched as child processes.
//

#if os(macOS)

import Foundation

// MARK: - Error

struct MCPClientError: Error, LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

// MARK: - Client

class MCPClient: @unchecked Sendable {
    private let config: MCPServerConfig
    private var process: Process?
    private var stdinPipe: Pipe?
    private var stdoutPipe: Pipe?
    private var requestId: Int = 0

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    /// Buffer for partial line reads from stdout.
    private var readBuffer = Data()

    init(config: MCPServerConfig) {
        self.config = config
    }

    var isRunning: Bool {
        process?.isRunning ?? false
    }

    // MARK: - Lifecycle

    func start() async throws {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: config.command)
        proc.arguments = config.args

        if let env = config.env {
            var environment = ProcessInfo.processInfo.environment
            for (key, value) in env {
                environment[key] = value
            }
            proc.environment = environment
        }

        let stdin = Pipe()
        let stdout = Pipe()
        let stderr = Pipe()

        proc.standardInput = stdin
        proc.standardOutput = stdout
        proc.standardError = stderr

        try proc.run()

        self.process = proc
        self.stdinPipe = stdin
        self.stdoutPipe = stdout
        self.readBuffer = Data()
    }

    func stop() {
        if let proc = process, proc.isRunning {
            proc.terminate()
        }
        process = nil
        stdinPipe = nil
        stdoutPipe = nil
        readBuffer = Data()
    }

    // MARK: - JSON-RPC Transport

    func sendRequest(method: String, params: [String: AnyCodableValue]?) async throws -> AnyCodableValue? {
        guard let proc = process, proc.isRunning else {
            throw MCPClientError(message: "MCP process is not running")
        }
        guard let stdinPipe = stdinPipe, let stdoutPipe = stdoutPipe else {
            throw MCPClientError(message: "Pipes are not configured")
        }

        requestId += 1
        let request = JSONRPCRequest(id: requestId, method: method, params: params)

        var data = try encoder.encode(request)
        data.append(contentsOf: [UInt8(ascii: "\n")])

        stdinPipe.fileHandleForWriting.write(data)

        // Read one newline-delimited JSON response using buffered reads
        let fileHandle = stdoutPipe.fileHandleForReading
        let responseData = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: MCPClientError(message: "Client deallocated"))
                    return
                }

                // Read in chunks until we find a newline
                while true {
                    // Check if buffer already contains a complete line
                    if let newlineIndex = self.readBuffer.firstIndex(of: UInt8(ascii: "\n")) {
                        let lineData = self.readBuffer[self.readBuffer.startIndex..<newlineIndex]
                        self.readBuffer = Data(self.readBuffer[(newlineIndex + 1)...])
                        continuation.resume(returning: Data(lineData))
                        return
                    }

                    // Read a chunk of data (up to 4KB at a time)
                    let chunk = fileHandle.readData(ofLength: 4096)
                    if chunk.isEmpty {
                        continuation.resume(throwing: MCPClientError(message: "MCP process closed stdout"))
                        return
                    }
                    self.readBuffer.append(chunk)
                }
            }
        }

        let response = try decoder.decode(JSONRPCResponse.self, from: responseData)

        if let error = response.error {
            throw MCPClientError(message: "JSON-RPC error \(error.code): \(error.message)")
        }

        return response.result
    }

    // MARK: - MCP Protocol Methods

    func initialize() async throws -> MCPInitializeResult {
        let params: [String: AnyCodableValue] = [
            "protocolVersion": .string("2024-11-05"),
            "capabilities": .object([:]),
            "clientInfo": .object([
                "name": .string("Re-Enchanted"),
                "version": .string("1.0.0")
            ])
        ]

        guard let result = try await sendRequest(method: "initialize", params: params) else {
            throw MCPClientError(message: "No result from initialize")
        }

        let resultData = try encoder.encode(result)
        let initResult = try decoder.decode(MCPInitializeResult.self, from: resultData)

        // Send initialized notification
        let notification = JSONRPCNotification(method: "notifications/initialized")
        var notifData = try encoder.encode(notification)
        notifData.append(contentsOf: [UInt8(ascii: "\n")])
        stdinPipe?.fileHandleForWriting.write(notifData)

        return initResult
    }

    func listTools() async throws -> [MCPToolDefinition] {
        guard let result = try await sendRequest(method: "tools/list", params: nil) else {
            throw MCPClientError(message: "No result from tools/list")
        }

        let resultData = try encoder.encode(result)
        let toolsList = try decoder.decode(MCPToolsListResult.self, from: resultData)
        return toolsList.tools
    }

    func callTool(name: String, arguments: [String: AnyCodableValue]) async throws -> String {
        let params: [String: AnyCodableValue] = [
            "name": .string(name),
            "arguments": .object(arguments)
        ]

        guard let result = try await sendRequest(method: "tools/call", params: params) else {
            throw MCPClientError(message: "No result from tools/call")
        }

        let resultData = try encoder.encode(result)
        let callResult = try decoder.decode(MCPToolCallResult.self, from: resultData)

        if callResult.isError == true {
            let errorText = callResult.content.compactMap { $0.text }.joined(separator: "\n")
            throw MCPClientError(message: "Tool error: \(errorText)")
        }

        return callResult.content
            .filter { $0.type == "text" }
            .compactMap { $0.text }
            .joined(separator: "\n")
    }
}

#endif
