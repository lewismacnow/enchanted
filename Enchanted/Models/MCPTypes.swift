//
//  MCPTypes.swift
//  Re-Enchanted
//

import Foundation

// MARK: - MCP Server Configuration

/// Configuration for an MCP server process.
public struct MCPServerConfig: Codable {
    public let name: String
    public let command: String
    public let args: [String]
    public let env: [String: String]?

    public init(name: String, command: String, args: [String], env: [String: String]? = nil) {
        self.name = name
        self.command = command
        self.args = args
        self.env = env
    }
}

// MARK: - MCP Tool & Resource Types

/// A tool definition exposed by an MCP server.
public struct MCPToolDefinition: Codable {
    public let name: String
    public let description: String?
    public let inputSchema: [String: AnyCodableValue]?

    public init(name: String, description: String? = nil, inputSchema: [String: AnyCodableValue]? = nil) {
        self.name = name
        self.description = description
        self.inputSchema = inputSchema
    }
}

/// A resource exposed by an MCP server.
public struct MCPResource: Codable {
    public let uri: String
    public let name: String
    public let description: String?
    public let mimeType: String?

    public init(uri: String, name: String, description: String? = nil, mimeType: String? = nil) {
        self.uri = uri
        self.name = name
        self.description = description
        self.mimeType = mimeType
    }
}

// MARK: - JSON-RPC 2.0 Types

/// A JSON-RPC 2.0 request message.
public struct JSONRPCRequest: Codable {
    public let jsonrpc: String
    public let id: Int
    public let method: String
    public let params: [String: AnyCodableValue]?

    public init(id: Int, method: String, params: [String: AnyCodableValue]? = nil) {
        self.jsonrpc = "2.0"
        self.id = id
        self.method = method
        self.params = params
    }
}

/// A JSON-RPC 2.0 response message.
public struct JSONRPCResponse: Codable {
    public let jsonrpc: String
    public let id: Int?
    public let result: AnyCodableValue?
    public let error: JSONRPCError?

    public init(jsonrpc: String = "2.0", id: Int? = nil, result: AnyCodableValue? = nil, error: JSONRPCError? = nil) {
        self.jsonrpc = jsonrpc
        self.id = id
        self.result = result
        self.error = error
    }
}

/// A JSON-RPC 2.0 error object.
public struct JSONRPCError: Codable {
    public let code: Int
    public let message: String
    public let data: AnyCodableValue?

    public init(code: Int, message: String, data: AnyCodableValue? = nil) {
        self.code = code
        self.message = message
        self.data = data
    }
}

/// A JSON-RPC 2.0 notification (no id, no response expected).
public struct JSONRPCNotification: Codable {
    public let jsonrpc: String
    public let method: String
    public let params: [String: AnyCodableValue]?

    public init(method: String, params: [String: AnyCodableValue]? = nil) {
        self.jsonrpc = "2.0"
        self.method = method
        self.params = params
    }
}

// MARK: - MCP Protocol Result Types

/// The result of an MCP `initialize` request.
public struct MCPInitializeResult: Codable {
    public let protocolVersion: String
    public let capabilities: MCPCapabilities
    public let serverInfo: MCPServerInfo

    public init(protocolVersion: String, capabilities: MCPCapabilities, serverInfo: MCPServerInfo) {
        self.protocolVersion = protocolVersion
        self.capabilities = capabilities
        self.serverInfo = serverInfo
    }
}

/// Capabilities reported by an MCP server.
public struct MCPCapabilities: Codable {
    public let tools: MCPToolsCapability?

    public init(tools: MCPToolsCapability? = nil) {
        self.tools = tools
    }
}

/// Capability details for MCP tools.
public struct MCPToolsCapability: Codable {
    public let listChanged: Bool?

    public init(listChanged: Bool? = nil) {
        self.listChanged = listChanged
    }
}

/// Information about an MCP server.
public struct MCPServerInfo: Codable {
    public let name: String
    public let version: String

    public init(name: String, version: String) {
        self.name = name
        self.version = version
    }
}

/// The result of an MCP `tools/list` request.
public struct MCPToolsListResult: Codable {
    public let tools: [MCPToolDefinition]

    public init(tools: [MCPToolDefinition]) {
        self.tools = tools
    }
}

/// The result of an MCP `tools/call` request.
public struct MCPToolCallResult: Codable {
    public let content: [MCPContent]
    public let isError: Bool?

    public init(content: [MCPContent], isError: Bool? = nil) {
        self.content = content
        self.isError = isError
    }
}

/// A content block returned from an MCP tool call.
public struct MCPContent: Codable {
    public let type: String
    public let text: String?

    public init(type: String, text: String? = nil) {
        self.type = type
        self.text = text
    }
}
