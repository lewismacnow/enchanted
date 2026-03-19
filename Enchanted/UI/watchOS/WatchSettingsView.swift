//
//  WatchSettingsView.swift
//  Re-Enchanted
//
//  Minimal settings for watchOS — provider URL and API key.
//

#if os(watchOS)
import SwiftUI

struct WatchSettingsView: View {
    @State private var providerType: ProviderSettings.ProviderType = .openai
    @State private var serverURL = ""
    @State private var apiKey = ""
    @State private var connectionStatus: ConnectionStatus = .unknown
    @State private var isTesting = false

    enum ConnectionStatus {
        case unknown, connected, failed
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Provider") {
                    Picker("Type", selection: $providerType) {
                        Text("OpenAI").tag(ProviderSettings.ProviderType.openai)
                        Text("Ollama").tag(ProviderSettings.ProviderType.ollama)
                    }

                    if providerType == .ollama {
                        Label("Ollama is not supported on Apple Watch", systemImage: "exclamationmark.triangle")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }

                Section("Connection") {
                    TextField("Server URL", text: $serverURL)
                        .textContentType(.URL)
                        .autocorrectionDisabled()
                        .font(.caption)

                    if providerType == .openai {
                        SecureField("API Key", text: $apiKey)
                            .font(.caption)
                    }
                }

                Section {
                    Button(action: saveSettings) {
                        Label("Save", systemImage: "checkmark.circle")
                    }

                    Button(action: testConnection) {
                        HStack {
                            Label("Test", systemImage: "antenna.radiowaves.left.and.right")
                            Spacer()
                            if isTesting {
                                ProgressView()
                                    .scaleEffect(0.7)
                            } else {
                                statusIndicator
                            }
                        }
                    }
                }
            }
            .navigationTitle("Settings")
        }
        .onAppear(perform: loadSettings)
    }

    @ViewBuilder
    private var statusIndicator: some View {
        switch connectionStatus {
        case .unknown:
            Image(systemName: "circle")
                .foregroundStyle(.secondary)
        case .connected:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
        }
    }

    private func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: "providerSettings"),
           let settings = try? JSONDecoder().decode(ProviderSettings.self, from: data) {
            providerType = settings.provider
            serverURL = settings.provider == .openai ? settings.openAIUri : settings.ollamaUri
            apiKey = settings.openAIKey
        }
    }

    private func saveSettings() {
        var settings = ProviderSettings()
        settings.provider = providerType

        if providerType == .openai {
            settings.openAIUri = serverURL
            settings.openAIKey = apiKey
            OpenAIService.shared.updateEndpoint(url: serverURL, key: apiKey)
        } else {
            settings.ollamaUri = serverURL
        }

        if let encoded = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(encoded, forKey: "providerSettings")
        }

        Haptics.shared.mediumTap()
    }

    private func testConnection() {
        isTesting = true
        connectionStatus = .unknown

        Task {
            let reachable: Bool
            if providerType == .openai {
                reachable = await OpenAIService.shared.reachable()
            } else {
                reachable = await OllamaService.shared.reachable()
            }

            await MainActor.run {
                connectionStatus = reachable ? .connected : .failed
                isTesting = false
                Haptics.shared.lightTap()
            }
        }
    }
}

#endif
