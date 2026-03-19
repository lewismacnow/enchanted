//
//  OllamaService.swift
//  Enchanted
//
//  Created by Augustinas Malinauskas on 09/12/2023.
//

import Foundation
import OllamaKit

class OllamaService: @unchecked Sendable {
    static let shared = OllamaService()
    
    var ollamaKit: OllamaKit
    
    init() {
        ollamaKit = OllamaKit(baseURL: URL(string: "http://localhost:11434")!)
        initEndpoint()
    }
    
    func initEndpoint(url: String? = nil, bearerToken: String? = "okki") {
        // Use default values for now
        let defaultUrl = "http://localhost:11434"
        let localStorageUrl = UserDefaults.standard.string(forKey: "ollamaUri")
        let localStorageBearerToken = UserDefaults.standard.string(forKey: "ollamaBearerToken")
        
        let ollamaUrl = url ?? localStorageUrl ?? defaultUrl
        let token = bearerToken ?? localStorageBearerToken ?? "okki"
        
        var finalUrl = ollamaUrl
        if !finalUrl.contains("http") {
            finalUrl = "http://" + finalUrl
        }
        
        if let url = URL(string: finalUrl) {
            ollamaKit =  OllamaKit(baseURL: url, bearerToken: token)
            return
        }
    }
    
    func getModels() async throws -> [LanguageModel] {
        let response = try await ollamaKit.models()
        let models = response.models.map {
            LanguageModel(
                name: $0.name,
                provider: .ollama,
                imageSupport: $0.details.families?.contains(where: { $0 == "clip" || $0 == "mllama" }) ?? false,
                thinkingSupport: LanguageModelSD.detectThinkingSupport(modelName: $0.name)
            )
        }
        return models
    }
    
    func reachable() async -> Bool {
        return await ollamaKit.reachable()
    }
}
