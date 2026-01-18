//
//  AppStore.swift
//  Enchanted
//
//  Created by Augustinas Malinauskas on 11/12/2023.
//

import Foundation
import Combine
import SwiftUI

// ProviderSettings is defined in Models/ProviderSettings.swift.
// If you see an error here, ensure that file is added to your App Target.

enum AppState {
    case chat
    case voice
}

@Observable
final class AppStore {
    static let shared = AppStore()
    
    private var cancellables = Set<AnyCancellable>()
    private var timer: Timer?
    private var pingInterval: TimeInterval = 5
    
    @MainActor var isReachable: Bool = true
    @MainActor var notifications: [NotificationMessage] = []
    @MainActor var menuBarIcon: String? = nil
    
    var appState: AppState = .chat
    
    @MainActor var providerSettings: ProviderSettings = ProviderSettings()
    
    init() {
        // Load settings asynchronously on the MainActor to avoid isolation issues
        Task { @MainActor in
            loadProviderSettings()
        }
        
        if let storedIntervalString = UserDefaults.standard.string(forKey: "pingInterval") {
            pingInterval = Double(storedIntervalString) ?? 5
            
            if pingInterval <= 0 {
                pingInterval = .infinity
            }
        }
        
        startCheckingReachability(interval: pingInterval)
    }
    
    @MainActor
    func updateProviderSettings(_ newSettings: ProviderSettings) {
        providerSettings = newSettings
        saveProviderSettings()
    }
    
    deinit {
        stopCheckingReachability()
    }
    
    private func startCheckingReachability(interval: TimeInterval = 5) {
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            Task { [weak self] in
                guard let self = self else { return }
                // reachable() is async and thread-safe
                let status = await self.reachable()
                // updateReachable is MainActor isolated, so we await it
                await self.updateReachable(status)
            }
        }
    }
    
    @MainActor
    private func updateReachable(_ isReachable: Bool) {
        withAnimation {
            self.isReachable = isReachable
        }
    }

    private func stopCheckingReachability() {
        timer?.invalidate()
        timer = nil
    }

    private func reachable() async -> Bool {
        // For now, just check Ollama (default) to avoid circular imports
        let status = await OllamaService.shared.reachable()
        return status
    }
    
    @MainActor
    private func loadProviderSettings() {
        if let data = UserDefaults.standard.data(forKey: "providerSettings"),
           let settings = try? JSONDecoder().decode(ProviderSettings.self, from: data) {
            providerSettings = settings
        } else {
            // Initialize with default settings
            providerSettings = ProviderSettings()
        }
    }
    
    @MainActor
    func saveProviderSettings() {
        if let data = try? JSONEncoder().encode(providerSettings) {
            UserDefaults.standard.set(data, forKey: "providerSettings")
        }
    }
    
    @MainActor
    func uiLog(message: String, status: NotificationMessage.Status) {
        notifications = [NotificationMessage(message: message, status: status)] + notifications.suffix(5)
    }
}
