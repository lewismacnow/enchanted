//
//  ConversationStatusView.swift
//  Re-Enchanted
//
//  Originally created by Augustinas Malinauskas on 10/12/2023.
//

import SwiftUI
import ActivityIndicatorView

struct ConversationStatusView: View {
    var state: ConversationState

    var body: some View {
        switch state {
        case .loading: EmptyView()
        case .completed: EmptyView()
        case .error(let message):
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.system(size: 14))

                Text(message)
                    .foregroundStyle(.red)
                    .font(.system(size: 13))
                    .lineLimit(3)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.red.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal)
        }
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    VStack(spacing: 12) {
        ConversationStatusView(state: .loading)
        ConversationStatusView(state: .completed)
        ConversationStatusView(state: .error(message: "Could not connect to Ollama server at localhost:11434"))
    }
    .padding()
}
