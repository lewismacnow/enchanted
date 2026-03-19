#if !os(watchOS)
//
//  ThinkingView.swift
//  Re-Enchanted
//
//  Collapsible chain-of-thought reasoning display with duration timer.
//

import SwiftUI

struct ThinkingView: View {
    let thinkContent: String?
    let isComplete: Bool
    let duration: Double?

    @State private var isExpanded: Bool = false
    @State private var elapsedSeconds: Int = 0
    @State private var timer: Timer?

    private var durationText: String {
        if let duration = duration {
            let seconds = Int(duration)
            if seconds < 60 {
                return "Thought for \(seconds)s"
            } else {
                let minutes = seconds / 60
                let remaining = seconds % 60
                return "Thought for \(minutes)m \(remaining)s"
            }
        } else if !isComplete {
            if elapsedSeconds < 60 {
                return "Thinking... \(elapsedSeconds)s"
            } else {
                let minutes = elapsedSeconds / 60
                let remaining = elapsedSeconds % 60
                return "Thinking... \(minutes)m \(remaining)s"
            }
        }
        return "Thought"
    }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            if let content = thinkContent, !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 3)
                        .clipShape(RoundedRectangle(cornerRadius: 1.5))

                    Text(content.trimmingCharacters(in: .whitespacesAndNewlines))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .padding(.leading, 12)
                        .padding(.vertical, 4)
                }
                .padding(.top, 4)
            }
        } label: {
            HStack(spacing: 6) {
                if !isComplete {
                    Image(systemName: "brain.head.profile")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .symbolEffect(.pulse, isActive: true)
                } else {
                    Image(systemName: "brain.head.profile")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(durationText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .tint(.secondary)
        .onAppear {
            // Start expanded while streaming, collapsed when complete
            isExpanded = !isComplete
            if !isComplete {
                startTimer()
            }
        }
        .onChange(of: isComplete) { _, complete in
            if complete {
                stopTimer()
                withAnimation(.easeOut(duration: 0.3)) {
                    isExpanded = false
                }
            }
        }
        .onDisappear {
            stopTimer()
        }
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            elapsedSeconds += 1
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

#Preview("Thinking in progress") {
    ThinkingView(
        thinkContent: "Let me analyze this step by step. First, I need to consider the main arguments...",
        isComplete: false,
        duration: nil
    )
    .padding()
}

#Preview("Thinking complete") {
    ThinkingView(
        thinkContent: "I considered the problem from multiple angles and determined the best approach.",
        isComplete: true,
        duration: 12.5
    )
    .padding()
}
#endif
