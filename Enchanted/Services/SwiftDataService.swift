//
//  SwiftDataService.swift
//  Re-Enchanted
//
//  Originally created by Augustinas Malinauskas on 10/12/2023.
//  Forked and maintained by iTomLab (itomlab.co.uk)
//

import Foundation
import SwiftData

final actor SwiftDataService: ModelActor {
    let modelContainer: ModelContainer
    let modelExecutor: ModelExecutor
    private let modelContext: ModelContext

    static let shared = SwiftDataService()

    init() {
        let sharedModelContainer: ModelContainer = {
            let schema = Schema([
                LanguageModelSD.self,
                ConversationSD.self,
                MessageSD.self,
                CompletionInstructionSD.self,
                PersonaSD.self,
                ScreenCaptureSD.self
            ])
            let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }()

        self.modelContext = ModelContext(sharedModelContainer)
        self.modelContext.autosaveEnabled = false
        modelContainer = sharedModelContainer
        modelExecutor = DefaultSerialModelExecutor(modelContext: modelContext)
    }
}

// MARK: - Language Models
extension SwiftDataService {
    func fetchModels() throws -> [LanguageModelSD] {
        let sortDescriptor = SortDescriptor(\LanguageModelSD.name)
        let fetchDescriptor = FetchDescriptor<LanguageModelSD>(sortBy: [sortDescriptor])
        return try modelContext.fetch(fetchDescriptor)
    }

    func saveModels(models: [LanguageModelSD]) throws {
        // Fetch existing models to preserve user-set properties (isHidden)
        let existing = try fetchModels()
        let existingByName = Dictionary(uniqueKeysWithValues: existing.map { ($0.name, $0) })

        for model in models {
            if let existingModel = existingByName[model.name] {
                // Update API-derived properties, preserve user-set properties
                existingModel.imageSupport = model.imageSupport
                existingModel.supportsThinking = model.supportsThinking
                existingModel.modelProvider = model.modelProvider
                existingModel.isAvailable = true
                // isHidden is NOT overwritten — preserved from existing record
            } else {
                // New model, insert fresh
                model.isAvailable = true
                modelContext.insert(model)
            }
        }
        try modelContext.saveChanges()
    }

    func updateModel(_ model: LanguageModelSD) throws {
        try modelContext.saveChanges()
    }

    func deleteModels() throws {
        try modelContext.delete(model: LanguageModelSD.self)
        try modelContext.saveChanges()
    }
}

// MARK: - Conversations
extension SwiftDataService {
    func createConversation(_ conversation: ConversationSD) throws {
        self.modelContext.insert(conversation)
        try modelContext.saveChanges()
    }

    func renameConversation(_ conversation: ConversationSD) throws {
        try modelContext.saveChanges()
    }

    func deleteConversation(_ conversation: ConversationSD) throws {
        self.modelContext.delete(conversation)
        try modelContext.saveChanges()
    }

    func updateConversation(_ conversation: ConversationSD) throws {
        conversation.updatedAt = .now
        try modelContext.saveChanges()
    }

    func fetchConversations() throws -> [ConversationSD] {
        let sortDescriptor = SortDescriptor(\ConversationSD.updatedAt, order: .reverse)
        let fetchDescriptor = FetchDescriptor<ConversationSD>(sortBy: [sortDescriptor])
        return try modelContext.fetch(fetchDescriptor)
    }

    func getConversation(_ conversationId: UUID) throws -> ConversationSD? {
        let predicate = #Predicate<ConversationSD> { $0.id == conversationId }
        let fetchDescriptor = FetchDescriptor<ConversationSD>(predicate: predicate)
        let conversations = try modelContext.fetch(fetchDescriptor)
        return conversations.first
    }

    func deleteConversations() throws {
        try modelContext.delete(model: ConversationSD.self)
        try modelContext.saveChanges()
    }

    func deleteMessages() throws {
        try modelContext.delete(model: MessageSD.self)
        try modelContext.saveChanges()
    }

    func deleteConversations(_ date: Date) throws {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? date
        let predicate = #Predicate<ConversationSD> { $0.createdAt >= dayStart && $0.createdAt < dayEnd }
        try modelContext.delete(model: ConversationSD.self, where: predicate)
        try modelContext.saveChanges()
    }
}

// MARK: - Messages
extension SwiftDataService {
    func fetchMessages(_ conversationId: UUID) throws -> [MessageSD] {
        let predicate = #Predicate<MessageSD> { $0.conversation?.id == conversationId }
        let sortDescriptor = SortDescriptor(\MessageSD.createdAt)
        let fetchDescriptor = FetchDescriptor<MessageSD>(predicate: predicate, sortBy: [sortDescriptor])
        return try modelContext.fetch(fetchDescriptor)
    }

    func updateMessage(_ message: MessageSD) throws {
        try modelContext.saveChanges()
    }

    func createMessage(_ message: MessageSD) throws {
        self.modelContext.insert(message)
        try modelContext.saveChanges()
    }
}

// MARK: - CompletionInstruction
extension SwiftDataService {
    func fetchCompletionInstructions() throws -> [CompletionInstructionSD] {
        let sortDescriptor = SortDescriptor(\CompletionInstructionSD.order, order: .forward)
        let fetchDescriptor = FetchDescriptor<CompletionInstructionSD>(sortBy: [sortDescriptor])
        return try modelContext.fetch(fetchDescriptor)
    }

    func updateCompletionInstructions(_ instructions: [CompletionInstructionSD]) throws {
        for index in instructions.indices {
            instructions[index].order = index
            modelContext.insert(instructions[index])
        }
        try modelContext.saveChanges()
    }

    func deleteCompletionInstruction(_ instruction: CompletionInstructionSD) throws {
        self.modelContext.delete(instruction)
        try modelContext.saveChanges()
    }
}

// MARK: - Personas
extension SwiftDataService {
    func fetchPersonas() throws -> [PersonaSD] {
        let fetchDescriptor = FetchDescriptor<PersonaSD>(sortBy: [])
        return try modelContext.fetch(fetchDescriptor)
    }

    func createPersona(_ persona: PersonaSD) throws {
        modelContext.insert(persona)
        try modelContext.saveChanges()
    }

    func updatePersona(_ persona: PersonaSD) throws {
        try modelContext.saveChanges()
    }

    func deletePersona(_ persona: PersonaSD) throws {
        modelContext.delete(persona)
        try modelContext.saveChanges()
    }
}

// MARK: - Screen Captures
extension SwiftDataService {
    func fetchScreenCaptures() throws -> [ScreenCaptureSD] {
        let sortDescriptor = SortDescriptor(\ScreenCaptureSD.timestamp, order: .reverse)
        let fetchDescriptor = FetchDescriptor<ScreenCaptureSD>(sortBy: [sortDescriptor])
        return try modelContext.fetch(fetchDescriptor)
    }

    func createScreenCapture(_ capture: ScreenCaptureSD) throws {
        modelContext.insert(capture)
        try modelContext.saveChanges()
    }

    func deleteScreenCapture(_ capture: ScreenCaptureSD) throws {
        modelContext.delete(capture)
        try modelContext.saveChanges()
    }
}

// MARK: - General
extension SwiftDataService {
    func deleteEverything() throws {
        try modelContext.delete(model: ConversationSD.self)
        try modelContext.delete(model: LanguageModelSD.self)
        try modelContext.delete(model: MessageSD.self)
        try modelContext.delete(model: CompletionInstructionSD.self)
        try modelContext.delete(model: PersonaSD.self)
        try modelContext.saveChanges()
    }
}
