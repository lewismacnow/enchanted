#if !os(watchOS)
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
    @State private var copiedField: String?

    private var statusIcon: String {
        if isError { return "exclamationmark.triangle.fill" }
        if result != nil { return "checkmark.circle.fill" }
        return "arrow.triangle.2.circlepath"
    }

    private var statusColor: Color {
        if isError { return .red }
        if result != nil { return .green }
        return .orange
    }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 8) {
                if !arguments.isEmpty {
                    codeSection(title: "Arguments", content: arguments, field: "args")
                }

                if let result = result {
                    codeSection(
                        title: isError ? "Error" : "Result",
                        content: result,
                        field: "result",
                        isError: isError
                    )
                }
            }
            .padding(.top, 4)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: statusIcon)
                    .font(.caption)
                    .foregroundStyle(statusColor)
                    .symbolEffect(.pulse, isActive: result == nil && !isError)

                Text(toolName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)

                Spacer()

                if result == nil && !isError {
                    Text("running...")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .tint(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private func codeSection(title: String, content: String, field: String, isError: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(isError ? .red : .secondary)

                Spacer()

                Button {
                    Clipboard.shared.setString(content)
                    copiedField = field
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        if copiedField == field { copiedField = nil }
                    }
                } label: {
                    Image(systemName: copiedField == field ? "checkmark" : "doc.on.doc")
                        .font(.caption2)
                        .foregroundStyle(copiedField == field ? .green : .secondary)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)
            }

            Text(content)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(isError ? .red : .secondary)
                .textSelection(.enabled)
                .lineLimit(20)
        }
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
#endif
