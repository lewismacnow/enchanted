//
//  MCPSettingsView.swift
//  Re-Enchanted
//
//  Manage MCP (Model Context Protocol) server connections.
//

import SwiftUI

#if os(macOS)
struct MCPSettingsView: View {
    @State private var mcpStore = MCPStore.shared
    @State private var showAddSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("MCP Servers")
                    .font(.headline)
                Spacer()
                Button(action: { showAddSheet = true }) {
                    Label("Add Server", systemImage: "plus")
                }
                .controlSize(.small)
            }
            .padding(.horizontal)
            .padding(.top, 12)

            Text("MCP servers provide tools that models can use during conversations. Tools are discovered automatically when connected.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.top, 4)
                .padding(.bottom, 8)

            if mcpStore.servers.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "wrench.and.screwdriver")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No MCP servers configured")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                List {
                    ForEach(mcpStore.servers, id: \.name) { server in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(server.name)
                                    .font(.body)
                                    .fontWeight(.medium)
                                Text("\(server.command) \(server.args.joined(separator: " "))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Button(role: .destructive) {
                                mcpStore.removeServer(server.name)
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.plain)
            }

            if !mcpStore.availableTools.isEmpty {
                Divider()
                    .padding(.horizontal)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Available Tools (\(mcpStore.availableTools.count))")
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal)
                    ForEach(mcpStore.availableTools, id: \.name) { tool in
                        HStack(spacing: 6) {
                            Image(systemName: "wrench")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(tool.name)
                                .font(.caption)
                            if let desc = tool.description {
                                Text(desc)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical, 8)
            }

            HStack {
                Spacer()
                Button("Connect All") {
                    Task { await mcpStore.connectAll() }
                }
                .controlSize(.small)
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddMCPServerSheet { config in
                mcpStore.addServer(config)
            }
        }
        .onAppear {
            mcpStore.loadServers()
        }
    }
}

struct AddMCPServerSheet: View {
    let onAdd: (MCPServerConfig) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var command = ""
    @State private var argsString = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("Add MCP Server")
                .font(.headline)

            Form {
                TextField("Name", text: $name)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                TextField("Command (e.g., npx)", text: $command)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                TextField("Arguments (space-separated)", text: $argsString)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Add") {
                    let args = argsString.components(separatedBy: " ").filter { !$0.isEmpty }
                    let config = MCPServerConfig(name: name, command: command, args: args)
                    onAdd(config)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty || command.isEmpty)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .frame(minWidth: 400, minHeight: 250)
    }
}
#endif
