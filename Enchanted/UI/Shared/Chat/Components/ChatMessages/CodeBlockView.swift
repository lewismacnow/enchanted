//
//  CodeBlockView.swift
//  Re-Enchanted
//
//  Originally created by Augustinas Malinauskas on 13/05/2024.
//

import SwiftUI
import MarkdownUI

struct CodeBlockView: View {
    var configuration: CodeBlockConfiguration
    @State private var copied = false

    var language: String {
        let language = configuration.language ?? "code"
        return language != "" ? language : "code"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(language)
                    .font(.system(size: 13, design: .monospaced))
                    .fontWeight(.semibold)
                Spacer()

                Button(action: {
                    Clipboard.shared.setString(configuration.content)
                    withAnimation(.easeInOut(duration: 0.2)) {
                        copied = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            copied = false
                        }
                    }
                }) {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .foregroundStyle(copied ? .green : .primary)
                        .padding(7)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(GrowingButton())
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
            .background(MarkdownColours.secondaryBackground)

            Divider()

            ScrollView(.horizontal) {
                configuration.label
                    .fixedSize(horizontal: false, vertical: true)
                    .relativeLineSpacing(.em(0.225))
                    .markdownTextStyle {
                        FontFamilyVariant(.monospaced)
                        FontSize(.em(0.85))
                    }
                    .padding(16)
            }
        }
        .background(MarkdownColours.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .markdownMargin(top: .zero, bottom: .em(0.8))
    }
}
