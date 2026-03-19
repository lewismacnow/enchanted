//
//  SettingsView.swift
//  Re-Enchanted
//
//  Originally created by Augustinas Malinauskas on 11/12/2023.
//  Forked and maintained by iTomLab (itomlab.co.uk)
//

import SwiftUI
import AVFoundation
import Foundation
import Combine

struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var systemPrompt: String
    @Binding var vibrations: Bool
    @Binding var colorScheme: AppColorScheme
    @Binding var defaultOllamModel: String
    @Binding var appUserInitials: String
    @Binding var pingInterval: String
    @Binding var voiceIdentifier: String
    @State var ollamaStatus: Bool?
    var save: () -> ()
    var checkServer: () -> ()
    var deleteAll: () -> ()
    var ollamaLangugeModels: [LanguageModelSD]
    var voices: [AVSpeechSynthesisVoice]
    @State private var appStore = AppStore.shared

    @State private var deleteConversationsDialog = false

    var body: some View {
        VStack {
            ZStack {
                HStack {
                    Button {
                        presentationMode.wrappedValue.dismiss()
                    } label: {
                        Text("Cancel")
                            .font(.system(size: 16))
                            .foregroundStyle(Color(.label))
                    }

                    Spacer()

                    Button(action: save) {
                        Text("Save")
                            .font(.system(size: 16))
                            .foregroundStyle(Color(.label))
                    }
                }

                HStack {
                    Spacer()
                    Text("Settings")
                        .font(.system(size: 16))
                        .fontWeight(.medium)
                        .foregroundStyle(Color(.label))
                    Spacer()
                }
            }
            .padding()

            Form {
                Section(header: Text("Provider").font(.headline)) {
                    Picker(selection: $appStore.providerSettings.provider) {
                        ForEach(ProviderSettings.ProviderType.allCases, id: \.self) { provider in
                            Text(provider.rawValue).tag(provider)
                        }
                    } label: {
                        Label("LLM Provider", systemImage: "server.rack")
                            .foregroundStyle(Color.label)
                    }
                }

                if appStore.providerSettings.provider == .ollama {
                    Section(header: Text("Ollama").font(.headline)) {
                        TextField("Ollama server URI", text: $appStore.providerSettings.ollamaUri, onCommit: checkServer)
                            .textContentType(.URL)
                            .disableAutocorrection(true)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
#if !os(macOS)
                            .padding(.top, 8)
                            .keyboardType(.URL)
                            .autocapitalization(.none)
#endif

                        TextField("Bearer Token", text: $appStore.providerSettings.ollamaBearerToken)
                            .disableAutocorrection(true)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
#if os(iOS)
                            .autocapitalization(.none)
#endif
                    }
                }

                if appStore.providerSettings.provider == .openai {
                    Section(header: Text("OpenAI Compatible").font(.headline)) {
                        TextField("API Endpoint URL", text: $appStore.providerSettings.openAIUri, onCommit: checkServer)
                            .textContentType(.URL)
                            .disableAutocorrection(true)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
#if !os(macOS)
                            .keyboardType(.URL)
                            .autocapitalization(.none)
#endif

                        SecureField("API Key (optional)", text: $appStore.providerSettings.openAIKey)
                            .disableAutocorrection(true)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
#if os(iOS)
                            .autocapitalization(.none)
#endif

                        Text("Works with any OpenAI-compatible endpoint: OpenAI, LM Studio, Ollama /v1, vLLM, etc.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section(header: Text("Models").font(.headline)) {
                    ModelManagementView()
                        .frame(minHeight: 200)
                }

                Section(header: Text("Chat").font(.headline)) {
                    VStack(alignment: .leading) {
                        Text("System prompt")
                        TextEditor(text: $systemPrompt)
                            .font(.system(size: 13))
                            .cornerRadius(4)
                            .multilineTextAlignment(.leading)
                            .frame(minHeight: 100)
                    }

                    Picker(selection: $defaultOllamModel) {
                        ForEach(ollamaLangugeModels, id: \.self) { model in
                            Text(model.name).tag(model.name)
                        }
                    } label: {
                        Label("Default Model", systemImage: "cpu")
                            .foregroundStyle(Color.label)
                    }

                    TextField("Ping Interval (seconds)", text: $pingInterval)
                        .disableAutocorrection(true)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }

                Section(header: Text("App").font(.headline)) {
#if os(iOS)
                    Toggle(isOn: $vibrations, label: {
                        Label("Vibrations", systemImage: "water.waves")
                            .foregroundStyle(Color.label)
                    })
#endif

                    Picker(selection: $colorScheme) {
                        ForEach(AppColorScheme.allCases, id: \.self) { scheme in
                            Text(scheme.toString).tag(scheme.id)
                        }
                    } label: {
                        Label("Appearance", systemImage: "sun.max")
                            .foregroundStyle(Color.label)
                    }

                    Picker(selection: $voiceIdentifier) {
                        ForEach(voices, id: \.self.identifier) { voice in
                            Text(voice.prettyName).tag(voice.identifier)
                        }
                    } label: {
                        Label("Voice", systemImage: "waveform")
                            .foregroundStyle(Color.label)

#if os(macOS)
                        Text("Download voices by going to Settings > Accessibility > Spoken Content > System Voice > Manage Voices.")
#else
                        Text("Download voices by going to Settings > Accessibility > Spoken Content > Voices.")
#endif

                        Button(action: {
#if os(macOS)
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.universalaccess?SpeakableItems") {
                                NSWorkspace.shared.open(url)
                            }
#else
                            let url = URL(string: "App-Prefs:root=General&path=ACCESSIBILITY")
                            if let url = url, UIApplication.shared.canOpenURL(url) {
                                UIApplication.shared.open(url, options: [:], completionHandler: nil)
                            }
#endif
                        }) {
                            Text("Open Settings")
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    TextField("Initials", text: $appUserInitials)
                        .disableAutocorrection(true)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
#if os(iOS)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
#endif

                    Button(action: { deleteConversationsDialog.toggle() }) {
                        HStack {
                            Spacer()
                            Text("Clear All Data")
                                .foregroundStyle(Color(.systemRed))
                                .padding(.vertical, 6)
                            Spacer()
                        }
                    }
                }
            }
            .formStyle(.grouped)
        }
        .preferredColorScheme(colorScheme.toiOSFormat)
        .confirmationDialog("Delete All Conversations?", isPresented: $deleteConversationsDialog) {
            Button("Delete", role: .destructive) { deleteAll() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Delete All Conversations?")
        }
    }
}

#Preview {
    SettingsView(
        systemPrompt: .constant("You are an intelligent assistant solving complex problems."),
        vibrations: .constant(true),
        colorScheme: .constant(.light),
        defaultOllamModel: .constant("llama2"),
        appUserInitials: .constant("AM"),
        pingInterval: .constant("5"),
        voiceIdentifier: .constant("sample"),
        save: {},
        checkServer: {},
        deleteAll: {},
        ollamaLangugeModels: LanguageModelSD.sample,
        voices: []
    )
}
