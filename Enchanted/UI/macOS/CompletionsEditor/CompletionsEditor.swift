//
//  Completions.swift
//  Re-Enchanted
//
//  Originally created by Augustinas Malinauskas on 01/03/2024.
//

#if os(macOS)
import SwiftUI

struct CompletionsEditor: View {
    @State private var completionsStore = CompletionsStore.shared
    @State private var accessibilityStatus = true
    @State private var timer: Timer?

    private func requestAccessibility() {
        Accessibility.shared.showAccessibilityInstructionsWindow()
        Accessibility.shared.simulateCopyKeyPress()
    }

    var body: some View {
        CompletionsEditorView(
            completions: $completionsStore.completions,
            onSave: completionsStore.save,
            onDelete: completionsStore.delete,
            accessibilityAccess: accessibilityStatus,
            requestAccessibilityAccess: requestAccessibility
        )
        .onAppear {
            timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
                let status = Accessibility.shared.checkAccessibility()
                DispatchQueue.main.async {
                    withAnimation {
                        accessibilityStatus = status
                    }
                }
            }
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
}
#endif
