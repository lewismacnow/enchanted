//
//  CompletionsStore.swift
//  Re-Enchanted
//
//  Originally created by Augustinas Malinauskas on 01/03/2024.
//  Forked and maintained by iTomLab (itomlab.co.uk)
//

import Foundation
import SwiftUI

@Observable
final class CompletionsStore: @unchecked Sendable {
    static let shared = CompletionsStore(swiftDataService: SwiftDataService.shared)
    private var swiftDataService: SwiftDataService

    @MainActor var completions: [CompletionInstructionSD] = []

    init(swiftDataService: SwiftDataService) {
        self.swiftDataService = swiftDataService
        load()
    }

    func save() {
        Task { @MainActor in
            let current = self.completions
            try? await swiftDataService.updateCompletionInstructions(current)
        }
    }

    func delete(_ completion: CompletionInstructionSD) {
        Task {
            try? await swiftDataService.deleteCompletionInstruction(completion)
            load()
        }
    }

    func load() {
        Task {
            nonisolated(unsafe) var loadedCompletions: [CompletionInstructionSD] = []
            loadedCompletions = (try? await SwiftDataService.shared.fetchCompletionInstructions()) ?? []

            if loadedCompletions.isEmpty {
                try? await SwiftDataService.shared.updateCompletionInstructions(CompletionInstructionSD.samples)
                loadedCompletions = (try? await SwiftDataService.shared.fetchCompletionInstructions()) ?? []
            }

            await MainActor.run {
                withAnimation {
                    self.completions = loadedCompletions
                }
            }
        }
    }
}
