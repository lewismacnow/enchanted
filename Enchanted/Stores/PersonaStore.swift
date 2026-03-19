//
//  PersonaStore.swift
//  Re-Enchanted
//
//  Manages Persona CRUD and state.
//

import Foundation
import SwiftData

@Observable
final class PersonaStore: @unchecked Sendable {
    static let shared = PersonaStore(swiftDataService: SwiftDataService.shared)

    private let swiftDataService: SwiftDataService
    @MainActor var personas: [PersonaSD] = []
    @MainActor var activePersona: PersonaSD?

    init(swiftDataService: SwiftDataService) {
        self.swiftDataService = swiftDataService
    }

    @MainActor var visiblePersonas: [PersonaSD] {
        personas.filter { !$0.isHidden }
    }

    func loadPersonas() async {
        do {
            nonisolated(unsafe) let fetched = try await swiftDataService.fetchPersonas()
            await MainActor.run {
                self.personas = fetched
            }
        } catch {
            print("Failed to load personas: \(error)")
        }
    }

    func createPersona(_ persona: PersonaSD) async {
        do {
            try await swiftDataService.createPersona(persona)
            await loadPersonas()
        } catch {
            print("Failed to create persona: \(error)")
        }
    }

    func deletePersona(_ persona: PersonaSD) async {
        do {
            try await swiftDataService.deletePersona(persona)
            await MainActor.run {
                if activePersona?.id == persona.id {
                    activePersona = nil
                }
            }
            await loadPersonas()
        } catch {
            print("Failed to delete persona: \(error)")
        }
    }

    func updatePersona(_ persona: PersonaSD) async {
        do {
            try await swiftDataService.updatePersona(persona)
            await loadPersonas()
        } catch {
            print("Failed to update persona: \(error)")
        }
    }

    @MainActor
    func selectPersona(_ persona: PersonaSD?) {
        activePersona = persona
    }

    @MainActor
    func clearPersona() {
        activePersona = nil
    }
}
