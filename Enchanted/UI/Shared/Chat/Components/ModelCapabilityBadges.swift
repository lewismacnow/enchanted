//
//  ModelCapabilityBadges.swift
//  Re-Enchanted
//
//  Shows capability indicators for a model (vision, thinking).
//

import SwiftUI

struct ModelCapabilityBadges: View {
    let supportsVision: Bool
    let supportsThinking: Bool

    var body: some View {
        HStack(spacing: 4) {
            if supportsVision {
                Image(systemName: "eye.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .help("Supports vision/image input")
            }
            if supportsThinking {
                Image(systemName: "brain.head.profile")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .help("Supports chain-of-thought reasoning")
            }
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        HStack {
            Text("qwen3:latest")
            ModelCapabilityBadges(supportsVision: false, supportsThinking: true)
        }
        HStack {
            Text("llava:latest")
            ModelCapabilityBadges(supportsVision: true, supportsThinking: false)
        }
        HStack {
            Text("gpt-4o")
            ModelCapabilityBadges(supportsVision: true, supportsThinking: true)
        }
    }
    .padding()
}
