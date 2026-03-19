//
//  MCPStore.swift
//  Re-Enchanted
//
//  Manages MCP server configurations and connections.
//  macOS only — MCP servers run as child processes via stdio.
//

#if os(macOS)

import Foundation

@Observable
final class MCPStore: @unchecked Sendable {
    static let shared = MCPStore()

    private static let userDefaultsKey = "mcpServers"

    @MainActor var servers: [MCPServerConfig] = []
    @MainActor var availableTools: [MCPToolDefinition] = []

    private var clients: [String: MCPClient] = [:]

    /// Maps tool name -> server name, for routing callTool requests.
    private var toolServerMap: [String: String] = [:]

    private init() {}

    // MARK: - Persistence

    func loadServers() {
        guard let data = UserDefaults.standard.data(forKey: Self.userDefaultsKey),
              let configs = try? JSONDecoder().decode([MCPServerConfig].self, from: data) else {
            return
        }
        Task { @MainActor in
            self.servers = configs
        }
    }

    func saveServers() {
        Task { @MainActor in
            if let data = try? JSONEncoder().encode(self.servers) {
                UserDefaults.standard.set(data, forKey: Self.userDefaultsKey)
            }
        }
    }

    // MARK: - Server Management

    func addServer(_ config: MCPServerConfig) {
        Task { @MainActor in
            self.servers.append(config)
        }
        saveServers()
    }

    func removeServer(_ name: String) {
        disconnect(name)
        Task { @MainActor in
            self.servers.removeAll { $0.name == name }
        }
        saveServers()
    }

    // MARK: - Connection Management

    func connectAll() async {
        let configs: [MCPServerConfig] = await MainActor.run { self.servers }

        for config in configs {
            do {
                let client = MCPClient(config: config)
                try await client.start()
                _ = try await client.initialize()
                let tools = try await client.listTools()

                clients[config.name] = client
                for tool in tools {
                    toolServerMap[tool.name] = config.name
                }

                await MainActor.run {
                    self.availableTools.append(contentsOf: tools)
                }
            } catch {
                print("Failed to connect MCP server '\(config.name)': \(error)")
            }
        }
    }

    func disconnect(_ name: String) {
        if let client = clients[name] {
            client.stop()
            clients.removeValue(forKey: name)
        }

        // Remove tools belonging to this server
        let toolNames = toolServerMap.filter { $0.value == name }.map { $0.key }
        for toolName in toolNames {
            toolServerMap.removeValue(forKey: toolName)
        }

        Task { @MainActor in
            self.availableTools.removeAll { toolNames.contains($0.name) }
        }
    }

    // MARK: - Tool Invocation

    func callTool(name: String, arguments: [String: AnyCodableValue]) async throws -> String {
        guard let serverName = toolServerMap[name],
              let client = clients[serverName] else {
            throw MCPClientError(message: "No MCP server provides tool '\(name)'")
        }

        return try await client.callTool(name: name, arguments: arguments)
    }

    // MARK: - OpenAI Conversion

    /// Converts available MCP tool definitions into OpenAI-compatible ToolDefinitions.
    @MainActor
    func convertToOpenAITools() -> [ToolDefinition] {
        let tools: [MCPToolDefinition] = availableTools
        return tools.map { mcpTool in
            ToolDefinition(
                function: FunctionDefinition(
                    name: mcpTool.name,
                    description: mcpTool.description,
                    parameters: mcpTool.inputSchema
                )
            )
        }
    }
}

#endif
