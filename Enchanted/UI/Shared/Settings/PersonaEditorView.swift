#if !os(watchOS)
//
//  PersonaEditorView.swift
//  Re-Enchanted
//
//  Create and manage Personas — virtual models with custom system prompts.
//

import SwiftUI

struct PersonaEditorView: View {
    @State private var personaStore = PersonaStore.shared
    @State private var languageModelStore = LanguageModelStore.shared
    @State private var showCreateSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center) {
                    Text("Personas")
                        .font(.headline)
                    Spacer()
                    Button(action: { showCreateSheet = true }) {
                        Label("New Persona", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .fixedSize()
                }
            }
            .padding(.horizontal)
            .padding(.top, 12)

            Text("Personas wrap a real model with a custom system prompt. Select a Persona from the model picker to use it.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.top, 4)
                .padding(.bottom, 8)

            if personaStore.personas.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "person.2.circle")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No personas yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Create a persona to get started")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                List {
                    ForEach(personaStore.personas) { persona in
                        PersonaRowView(persona: persona) {
                            Task { await personaStore.deletePersona(persona) }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            CreatePersonaSheet(models: languageModelStore.models) { persona in
                Task { await personaStore.createPersona(persona) }
            }
        }
        .task {
            await personaStore.loadPersonas()
        }
    }
}

// MARK: - Persona Row

struct PersonaRowView: View {
    let persona: PersonaSD
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: persona.icon)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(persona.name)
                    .font(.body)
                    .fontWeight(.medium)

                HStack(spacing: 6) {
                    if let model = persona.baseModel {
                        Text(model.prettyName)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }

                Text(persona.systemPrompt)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Create Sheet

struct CreatePersonaSheet: View {
    let models: [LanguageModelSD]
    let onCreate: (PersonaSD) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var icon = "person.fill"
    @State private var systemPrompt = ""
    @State private var selectedModelName = ""

    private let iconOptions = [
        "person.fill", "chevron.left.forwardslash.chevron.right", "pencil.line",
        "lightbulb", "brain.head.profile", "book.fill", "wrench.and.screwdriver",
        "shield.checkered", "globe", "text.magnifyingglass",
        "doc.text", "paintbrush", "function", "terminal"
    ]

    var body: some View {
        VStack(spacing: 16) {
            Text("New Persona")
                .font(.headline)

            Form {
                TextField("Name", text: $name)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                Picker("Icon", selection: $icon) {
                    ForEach(iconOptions, id: \.self) { iconName in
                        Label(iconName, systemImage: iconName)
                            .tag(iconName)
                    }
                }

                Picker("Base Model", selection: $selectedModelName) {
                    Text("Select a model").tag("")
                    ForEach(models, id: \.name) { model in
                        Text(model.name).tag(model.name)
                    }
                }

                VStack(alignment: .leading) {
                    Text("System Prompt")
                    TextEditor(text: $systemPrompt)
                        .font(.system(size: 13))
                        .frame(minHeight: 120)
                        .cornerRadius(4)
                }
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Create") {
                    let baseModel = models.first { $0.name == selectedModelName }
                    let persona = PersonaSD(
                        name: name,
                        icon: icon,
                        systemPrompt: systemPrompt,
                        baseModel: baseModel
                    )
                    onCreate(persona)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty || systemPrompt.isEmpty || selectedModelName.isEmpty)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .frame(minWidth: 450, minHeight: 400)
        .onAppear {
            if let first = models.first {
                selectedModelName = first.name
            }
        }
    }
}

#Preview {
    PersonaEditorView()
        .frame(width: 500, height: 400)
}
#endif
