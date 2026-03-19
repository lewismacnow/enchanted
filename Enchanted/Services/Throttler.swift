//
//  Throttler.swift
//  Re-Enchanted
//
//  Originally created by Augustinas Malinauskas on 29/12/2023.
//  Forked and maintained by iTomLab (itomlab.co.uk)
//

import Foundation

class Throttler {
    private var workItem: DispatchWorkItem?
    private var lastRun: Date = .distantPast
    private let queue: DispatchQueue
    private let delay: TimeInterval
    private var pendingBlock: (() -> Void)?

    init(delay: TimeInterval, queue: DispatchQueue = DispatchQueue.main) {
        self.delay = delay
        self.queue = queue
    }

    func throttle(_ block: @escaping () -> Void) {
        workItem?.cancel()
        pendingBlock = block

        let item = DispatchWorkItem { [weak self] in
            self?.lastRun = Date()
            self?.pendingBlock?()
            self?.pendingBlock = nil
        }
        self.workItem = item

        let delayFactor = Date().timeIntervalSince(lastRun) >= delay ? 0 : delay
        queue.asyncAfter(deadline: .now() + delayFactor, execute: item)
    }

    /// Force execution of the last pending block immediately.
    /// Call this when streaming completes to ensure no content is lost.
    func flush() {
        workItem?.cancel()
        if let pending = pendingBlock {
            queue.async { [weak self] in
                pending()
                self?.pendingBlock = nil
            }
        }
    }
}
