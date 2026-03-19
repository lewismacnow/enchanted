//
//  WatchMessageRow.swift
//  Re-Enchanted
//
//  Simplified message display for watchOS.
//

#if os(watchOS)
import SwiftUI

struct WatchMessageRow: View {
    let message: MessageSD

    /// Strip <think>...</think> tags and return the visible content
    private var displayContent: String {
        (message.realContent ?? message.content).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isThinking: Bool {
        message.hasThink && !message.thinkComplete
    }

    private var thinkingDurationText: String? {
        if let duration = message.thinkingDuration, duration > 0 {
            return "Thought for \(Int(duration))s"
        }
        return nil
    }

    var body: some View {
        VStack(alignment: message.role == "user" ? .trailing : .leading, spacing: 2) {
            // Thinking indicator
            if message.role == "assistant" {
                if isThinking {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.5)
                        Text("Thinking...")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                } else if let durationText = thinkingDurationText {
                    Text(durationText)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }

            // Message bubble
            if !displayContent.isEmpty {
                Text(displayContent)
                    .font(.system(size: 13))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(bubbleBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .frame(maxWidth: .infinity, alignment: message.role == "user" ? .trailing : .leading)
            }

            // Error state
            if message.error {
                Label("Error", systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 2)
    }

    private var bubbleBackground: some ShapeStyle {
        if message.role == "user" {
            return Color.blue.opacity(0.3)
        } else {
            return Color.secondary.opacity(0.15)
        }
    }
}

#endif
