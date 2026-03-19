//
//  ToolCallView.swift
//  Re-Enchanted
//
//  Displays tool call invocations inline in chat messages.
//

import SwiftUI

struct ToolCallView: View {
    let toolName: String
    let arguments: String
    let result: String?
    let isError: Bool

    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 8) {
                if !arguments.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Arguments")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                        Text(arguments)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }

                if let result = result {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Result")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(isError ? .red : .secondary)
                        Text(result)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(isError ? .red : .secondary)
                            .textSelection(.enabled)
                            .lineLimit(10)
                    }
                }
            }
            .padding(.top, 4)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isError ? "exclamationmark.triangle" : "wrench")
                    .font(.caption)
                    .foregroundStyle(isError ? .red : .orange)
                Text(toolName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                if result != nil {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.green)
                }
            }
        }
        .tint(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    VStack(spacing: 12) {
        ToolCallView(
            toolName: "read_file",
            arguments: "{\"path\": \"/tmp/test.txt\"}",
            result: "Hello, World!",
            isError: false
        )
        ToolCallView(
            toolName: "web_search",
            arguments: "{\"query\": \"swift concurrency\"}",
            result: nil,
            isError: false
        )
        ToolCallView(
            toolName: "execute_command",
            arguments: "{\"command\": \"ls -la\"}",
            result: "Permission denied",
            isError: true
        )
    }
    .padding()
}
