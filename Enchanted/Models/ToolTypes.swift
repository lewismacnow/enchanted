//
//  ToolTypes.swift
//  Re-Enchanted
//

import Foundation

// MARK: - AnyCodableValue

/// A type-erased Codable value for representing arbitrary JSON values,
/// used for JSON Schema representation of tool parameters.
public enum AnyCodableValue: Codable, Equatable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([AnyCodableValue])
    case object([String: AnyCodableValue])
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
            return
        }
        if let boolValue = try? container.decode(Bool.self) {
            self = .bool(boolValue)
            return
        }
        if let intValue = try? container.decode(Int.self) {
            self = .int(intValue)
            return
        }
        if let doubleValue = try? container.decode(Double.self) {
            self = .double(doubleValue)
            return
        }
        if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
            return
        }
        if let arrayValue = try? container.decode([AnyCodableValue].self) {
            self = .array(arrayValue)
            return
        }
        if let objectValue = try? container.decode([String: AnyCodableValue].self) {
            self = .object(objectValue)
            return
        }

        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "AnyCodableValue cannot decode value"
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
}

// MARK: - OpenAI Tool Calling Types

/// Defines a tool available for the model to call.
public struct ToolDefinition: Codable {
    public let type: String
    public let function: FunctionDefinition

    public init(function: FunctionDefinition) {
        self.type = "function"
        self.function = function
    }
}

/// Describes a function that can be called by the model.
public struct FunctionDefinition: Codable {
    public let name: String
    public let description: String?
    public let parameters: [String: AnyCodableValue]?

    public init(name: String, description: String? = nil, parameters: [String: AnyCodableValue]? = nil) {
        self.name = name
        self.description = description
        self.parameters = parameters
    }
}

/// Represents a tool call made by the model in a response.
public struct ToolCall: Codable {
    public let id: String
    public let type: String
    public let function: ToolCallFunction

    public init(id: String, type: String = "function", function: ToolCallFunction) {
        self.id = id
        self.type = type
        self.function = function
    }
}

/// The function invocation details within a tool call.
public struct ToolCallFunction: Codable {
    public let name: String
    public let arguments: String

    public init(name: String, arguments: String) {
        self.name = name
        self.arguments = arguments
    }
}

/// A message containing the result of a tool call, sent back to the model.
public struct ToolCallResponse: Codable {
    public let role: String
    public let tool_call_id: String
    public let content: String

    public init(tool_call_id: String, content: String) {
        self.role = "tool"
        self.tool_call_id = tool_call_id
        self.content = content
    }
}
