//
//  ToolbarView_macOS.swift
//  Re-Enchanted
//
//  Originally created by Augustinas Malinauskas on 10/02/2024.
//

#if os(macOS) || os(visionOS)
import SwiftUI

struct ToolbarView: View {
    var modelsList: [LanguageModelSD]
    var personas: [PersonaSD] = []
    var selectedModel: LanguageModelSD?
    var activePersona: PersonaSD?
    var onSelectModel: @MainActor (_ model: LanguageModelSD?) -> ()
    var onSelectPersona: (@MainActor (_ persona: PersonaSD) -> Void)?
    var onNewConversationTap: () -> ()
    var copyChat: (_ json: Bool) -> ()

    var body: some View {
        ModelSelectorView(
            modelsList: modelsList,
            personas: personas,
            selectedModel: selectedModel,
            activePersona: activePersona,
            onSelectModel: onSelectModel,
            onSelectPersona: onSelectPersona,
            showChevron: false
        )
        .frame(height: 20)

        MoreOptionsMenuView(copyChat: copyChat)

        Button(action: onNewConversationTap) {
            Image(systemName: "square.and.pencil")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(height: 20)
                .padding(5)
        }
        .buttonStyle(PlainButtonStyle())
        .keyboardShortcut(KeyEquivalent("n"), modifiers: .command)
    }
}

#Preview {
    ToolbarView(
        modelsList: LanguageModelSD.sample,
        selectedModel: LanguageModelSD.sample[0],
        onSelectModel: { _ in },
        onNewConversationTap: {},
        copyChat: { _ in }
    )
}

#endif
