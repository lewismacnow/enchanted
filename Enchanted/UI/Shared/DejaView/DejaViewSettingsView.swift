//
//  DejaViewSettingsView.swift
//  Re-Enchanted
//
//  Configuration view for DejaView capture settings and vector store backend.
//

import SwiftUI

struct DejaViewSettingsView: View {
    @State private var dejaViewStore = DejaViewStore.shared

    @State private var connectionURL = ""
    @State private var visionModel: String = UserDefaults.standard.string(forKey: "dejaViewVisionModel") ?? ""

    private let intervalOptions: [(label: String, value: TimeInterval)] = [
        ("10 seconds", 10),
        ("30 seconds", 30),
        ("60 seconds", 60),
        ("5 minutes", 300)
    ]

    private let retentionOptions: [(label: String, value: Int)] = [
        ("7 days", 7),
        ("14 days", 14),
        ("30 days", 30),
        ("60 days", 60),
        ("90 days", 90),
        ("Forever", 0)
    ]

    private let vectorStoreOptions: [(label: String, value: String)] = [
        ("Local", "local"),
        ("pgvector", "pgvector"),
        ("ChromaDB", "chromadb"),
        ("Qdrant", "qdrant")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("DejaView Settings")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top, 12)

            Text("Configure screen capture behaviour and vector store backend.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.top, 4)
                .padding(.bottom, 8)

            Form {
                // MARK: - Capture Section
                Section("Capture") {
                    #if os(macOS)
                    HStack {
                        Toggle("Enable Capture", isOn: Binding(
                            get: { dejaViewStore.isCapturing },
                            set: { enabled in
                                if enabled {
                                    dejaViewStore.startCapturing()
                                } else {
                                    dejaViewStore.stopCapturing()
                                }
                            }
                        ))

                        Spacer()

                        captureStatusBadge
                    }
                    #else
                    HStack {
                        Text("Screen capture")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("macOS only")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    #endif

                    Picker("Capture Interval", selection: Binding(
                        get: { dejaViewStore.captureInterval },
                        set: { dejaViewStore.captureInterval = $0 }
                    )) {
                        ForEach(intervalOptions, id: \.value) { option in
                            Text(option.label).tag(option.value)
                        }
                    }

                    Picker("Retention Period", selection: Binding(
                        get: { dejaViewStore.retentionDays },
                        set: { dejaViewStore.retentionDays = $0 }
                    )) {
                        ForEach(retentionOptions, id: \.value) { option in
                            Text(option.label).tag(option.value)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Vision Model (optional)", text: $visionModel)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .onChange(of: visionModel) { _, newValue in
                                UserDefaults.standard.set(newValue, forKey: "dejaViewVisionModel")
                            }
                        Text("e.g. \"llava:latest\" or \"gpt-4o\". When set, screenshots are described by this vision model for better search. Leave empty to skip.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }

                // MARK: - Vector Store Section
                Section("Vector Store") {
                    Picker("Backend", selection: Binding(
                        get: { dejaViewStore.vectorStoreType },
                        set: { dejaViewStore.vectorStoreType = $0 }
                    )) {
                        ForEach(vectorStoreOptions, id: \.value) { option in
                            Text(option.label).tag(option.value)
                        }
                    }

                    if dejaViewStore.vectorStoreType != "local" {
                        connectionFields
                    }
                }

                // MARK: - Info Section
                Section("Status") {
                    HStack {
                        Text("Stored captures")
                        Spacer()
                        Text("\(dejaViewStore.captures.count)")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Vector store")
                        Spacer()
                        Text(currentVectorStoreLabel)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
            }
            .formStyle(.grouped)
        }
        .task {
            await dejaViewStore.loadCaptures()
            loadConnectionURL()
        }
    }

    // MARK: - Subviews

    #if os(macOS)
    private var captureStatusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(dejaViewStore.isCapturing ? Color.green : Color.secondary)
                .frame(width: 8, height: 8)
            Text(dejaViewStore.isCapturing ? "Active" : "Inactive")
                .font(.caption)
                .foregroundStyle(dejaViewStore.isCapturing ? .primary : .secondary)
        }
    }
    #endif

    @ViewBuilder
    private var connectionFields: some View {
        let storeType = dejaViewStore.vectorStoreType

        TextField(urlPlaceholder(for: storeType), text: $connectionURL)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .onChange(of: connectionURL) { _, newValue in
                saveConnectionURL(newValue)
            }

        Text(urlHelp(for: storeType))
            .font(.caption)
            .foregroundStyle(.tertiary)
    }

    // MARK: - Helpers

    private var currentVectorStoreLabel: String {
        vectorStoreOptions.first { $0.value == dejaViewStore.vectorStoreType }?.label ?? "Unknown"
    }

    private func urlPlaceholder(for type: String) -> String {
        switch type {
        case "pgvector": return "postgresql://localhost:5432/dejaview"
        case "chromadb": return "http://localhost:8000"
        case "qdrant": return "http://localhost:6333"
        default: return ""
        }
    }

    private func urlHelp(for type: String) -> String {
        switch type {
        case "pgvector": return "PostgreSQL connection string with pgvector extension."
        case "chromadb": return "ChromaDB HTTP API endpoint."
        case "qdrant": return "Qdrant REST API endpoint."
        default: return ""
        }
    }

    private var connectionURLKey: String {
        switch dejaViewStore.vectorStoreType {
        case "pgvector": return "dejaViewPgvectorURL"
        case "chromadb": return "dejaViewChromaURL"
        case "qdrant": return "dejaViewQdrantURL"
        default: return ""
        }
    }

    private func loadConnectionURL() {
        let key = connectionURLKey
        guard !key.isEmpty else { return }
        connectionURL = UserDefaults.standard.string(forKey: key) ?? ""
    }

    private func saveConnectionURL(_ value: String) {
        let key = connectionURLKey
        guard !key.isEmpty else { return }
        UserDefaults.standard.set(value, forKey: key)
    }
}

#Preview {
    DejaViewSettingsView()
        .frame(width: 500, height: 500)
}
