//
//  AppStore.swift
//  Re-Enchanted
//
//  Originally created by Augustinas Malinauskas on 11/12/2023.
//  Forked and maintained by iTomLab (itomlab.co.uk)
//

import Foundation
import Combine
import SwiftUI

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

        // Update services with new settings
        OllamaService.shared.initEndpoint(url: newSettings.ollamaUri, bearerToken: newSettings.ollamaBearerToken)
        OpenAIService.shared.updateEndpoint(url: newSettings.openAIUri, key: newSettings.openAIKey)
    }

    deinit {
        stopCheckingReachability()
    }

    private func startCheckingReachability(interval: TimeInterval = 5) {
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            Task { [weak self] in
                guard let self = self else { return }
                let status = await self.reachable()
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
        let provider = await MainActor.run { providerSettings.provider }
        switch provider {
        case .ollama:
            return await OllamaService.shared.reachable()
        case .openai:
            return await OpenAIService.shared.reachable()
        }
    }

    @MainActor
    private func loadProviderSettings() {
        if let data = UserDefaults.standard.data(forKey: "providerSettings"),
           let settings = try? JSONDecoder().decode(ProviderSettings.self, from: data) {
            providerSettings = settings
        } else {
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
