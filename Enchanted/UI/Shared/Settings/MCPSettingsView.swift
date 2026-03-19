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

// MARK: - Preset

private struct MCPPreset {
    let name: String
    let command: String
    let args: [String]
    let env: [String: String]

    static let presets: [MCPPreset] = [
        MCPPreset(
            name: "Filesystem",
            command: "npx",
            args: ["-y", "@modelcontextprotocol/server-filesystem", "/tmp"],
            env: [:]
        ),
        MCPPreset(
            name: "GitHub",
            command: "npx",
            args: ["-y", "@modelcontextprotocol/server-github"],
            env: ["GITHUB_TOKEN": "your-token-here"]
        ),
        MCPPreset(
            name: "Brave Search",
            command: "npx",
            args: ["-y", "@modelcontextprotocol/server-brave-search"],
            env: ["BRAVE_API_KEY": "your-api-key-here"]
        ),
        MCPPreset(
            name: "Memory",
            command: "npx",
            args: ["-y", "@modelcontextprotocol/server-memory"],
            env: [:]
        ),
        MCPPreset(
            name: "Fetch",
            command: "npx",
            args: ["-y", "@modelcontextprotocol/server-fetch"],
            env: [:]
        )
    ]
}

// MARK: - Add Sheet

struct AddMCPServerSheet: View {
    let onAdd: (MCPServerConfig) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var command = ""
    @State private var argsString = ""
    @State private var envPairs: [(key: String, value: String)] = []
    @State private var showImportJSON = false
    @State private var importJSONText = ""
    @State private var importError = ""

    var body: some View {
        VStack(spacing: 0) {
            Text("Add MCP Server")
                .font(.headline)
                .padding(.top, 16)
                .padding(.bottom, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // MARK: Quick Add Presets
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Quick Add")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 6) {
                            ForEach(MCPPreset.presets, id: \.name) { preset in
                                Button {
                                    applyPreset(preset)
                                } label: {
                                    Text(preset.name)
                                        .font(.caption)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 6)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                    }
                    .padding(.horizontal)

                    Divider()

                    // MARK: Import from JSON
                    VStack(alignment: .leading, spacing: 8) {
                        Button {
                            showImportJSON.toggle()
                        } label: {
                            Label(
                                showImportJSON ? "Hide JSON Import" : "Import from JSON",
                                systemImage: "doc.text"
                            )
                            .font(.subheadline)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.blue)

                        if showImportJSON {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Paste the mcpServers object from claude_desktop_config.json:")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                TextEditor(text: $importJSONText)
                                    .font(.system(.caption, design: .monospaced))
                                    .frame(height: 120)
                                    .border(Color.secondary.opacity(0.3))

                                if !importError.isEmpty {
                                    Text(importError)
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                }

                                Button("Import All Servers") {
                                    importFromJSON()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .disabled(importJSONText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                        }
                    }
                    .padding(.horizontal)

                    Divider()

                    // MARK: Manual Configuration
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Server Configuration")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        TextField("Name", text: $name)
                            .textFieldStyle(RoundedBorderTextFieldStyle())

                        TextField("Command (e.g., npx)", text: $command)
                            .textFieldStyle(RoundedBorderTextFieldStyle())

                        TextField("Arguments (space-separated)", text: $argsString)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    .padding(.horizontal)

                    // MARK: Environment Variables
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Environment Variables")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                            Button {
                                envPairs.append((key: "", value: ""))
                            } label: {
                                Image(systemName: "plus.circle")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.blue)
                        }

                        if envPairs.isEmpty {
                            Text("No environment variables. Tap + to add.")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        } else {
                            ForEach(envPairs.indices, id: \.self) { index in
                                HStack(spacing: 4) {
                                    TextField("KEY", text: Binding(
                                        get: { envPairs[index].key },
                                        set: { envPairs[index].key = $0 }
                                    ))
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .frame(maxWidth: .infinity)

                                    Text("=")
                                        .foregroundStyle(.secondary)

                                    TextField("value", text: Binding(
                                        get: { envPairs[index].value },
                                        set: { envPairs[index].value = $0 }
                                    ))
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .frame(maxWidth: .infinity)

                                    Button {
                                        envPairs.remove(at: index)
                                    } label: {
                                        Image(systemName: "minus.circle")
                                            .foregroundStyle(.red)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
            }

            Divider()

            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Add") {
                    let args = argsString.components(separatedBy: " ").filter { !$0.isEmpty }
                    let env = buildEnvDict()
                    let config = MCPServerConfig(
                        name: name,
                        command: command,
                        args: args,
                        env: env.isEmpty ? nil : env
                    )
                    onAdd(config)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty || command.isEmpty)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .frame(minWidth: 480, minHeight: 500)
    }

    // MARK: - Helpers

    private func applyPreset(_ preset: MCPPreset) {
        name = preset.name
        command = preset.command
        argsString = preset.args.joined(separator: " ")
        envPairs = preset.env.map { (key: $0.key, value: $0.value) }
            .sorted { $0.key < $1.key }
    }

    private func buildEnvDict() -> [String: String] {
        var dict: [String: String] = [:]
        for pair in envPairs where !pair.key.isEmpty {
            dict[pair.key] = pair.value
        }
        return dict
    }

    /// Parse Claude Desktop format JSON: { "serverName": { "command": "...", "args": [...], "env": {...} }, ... }
    private func importFromJSON() {
        importError = ""

        let trimmed = importJSONText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8) else {
            importError = "Invalid text encoding."
            return
        }

        do {
            guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                importError = "Expected a JSON object with server names as keys."
                return
            }

            var addedCount = 0
            for (serverName, value) in root {
                guard let serverDict = value as? [String: Any],
                      let cmd = serverDict["command"] as? String else {
                    continue
                }

                let args = serverDict["args"] as? [String] ?? []
                let envDict = serverDict["env"] as? [String: String]

                let config = MCPServerConfig(
                    name: serverName,
                    command: cmd,
                    args: args,
                    env: envDict
                )
                onAdd(config)
                addedCount += 1
            }

            if addedCount > 0 {
                dismiss()
            } else {
                importError = "No valid server configurations found in JSON."
            }
        } catch {
            importError = "JSON parse error: \(error.localizedDescription)"
        }
    }
}
#endif
