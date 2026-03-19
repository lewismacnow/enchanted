//
//  Menus.swift
//  Re-Enchanted
//
//  Originally created by Wildan Zulfikar on 24.4.2024.
//

import Foundation
import SwiftUI

#if os(macOS)

// MARK: - Focused Value Keys

struct ShowSettingsKey: FocusedValueKey {
    typealias Value = Binding<Bool>
}

struct FocusInputKey: FocusedValueKey {
    typealias Value = () -> Void
}

struct NewConversationKey: FocusedValueKey {
    typealias Value = () -> Void
}

struct ExportChatKey: FocusedValueKey {
    typealias Value = () -> Void
}

extension FocusedValues {
    var showSettings: Binding<Bool>? {
        get { self[ShowSettingsKey.self] }
        set { self[ShowSettingsKey.self] = newValue }
    }
    var focusInput: (() -> Void)? {
        get { self[FocusInputKey.self] }
        set { self[FocusInputKey.self] = newValue }
    }
    var newConversation: (() -> Void)? {
        get { self[NewConversationKey.self] }
        set { self[NewConversationKey.self] = newValue }
    }
    var exportChat: (() -> Void)? {
        get { self[ExportChatKey.self] }
        set { self[ExportChatKey.self] = newValue }
    }
}

// MARK: - Menu Commands

struct Menus: Commands {
    @FocusedValue(\.showSettings) var showSettings
    @FocusedValue(\.focusInput) var focusInput
    @FocusedValue(\.newConversation) var newConversation
    @FocusedValue(\.exportChat) var exportChat

    var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button("Settings") {
                showSettings?.wrappedValue = true
            }
            .keyboardShortcut(",", modifiers: .command)
        }

        CommandGroup(after: .newItem) {
            Button("New Conversation") {
                newConversation?()
            }
            .keyboardShortcut("n", modifiers: .command)

            Divider()

            Button("Focus Message Input") {
                focusInput?()
            }
            .keyboardShortcut("/", modifiers: .command)

            Button("Export Chat") {
                exportChat?()
            }
            .keyboardShortcut("e", modifiers: .command)
        }
    }
}
#endif
