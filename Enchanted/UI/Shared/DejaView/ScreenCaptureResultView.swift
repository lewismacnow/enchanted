#if !os(watchOS)
//
//  ScreenCaptureResultView.swift
//  Re-Enchanted
//
//  Displays a single screen capture search result with thumbnail, text preview, and score.
//

import SwiftUI

struct ScreenCaptureResultView: View {
    let capture: ScreenCaptureSD
    let score: Float
    let onDelete: () -> Void

    private var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: capture.timestamp)
    }

    private var scorePercentage: String {
        "\(Int(score * 100))%"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Thumbnail
            thumbnailView
                .frame(width: 133, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            // Details
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(formattedTimestamp)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Spacer()

                    Text(scorePercentage)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(scoreColor.opacity(0.15))
                        .foregroundStyle(scoreColor)
                        .clipShape(Capsule())
                }

                Text(capture.extractedText.isEmpty ? "No text extracted" : capture.extractedText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Thumbnail

    @ViewBuilder
    private var thumbnailView: some View {
        let expandedPath = (capture.imagePath as NSString).expandingTildeInPath

        #if os(macOS)
        if let nsImage = NSImage(contentsOfFile: expandedPath) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            placeholderImage
        }
        #else
        if let uiImage = UIImage(contentsOfFile: expandedPath) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            placeholderImage
        }
        #endif
    }

    private var placeholderImage: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.15))
            .overlay {
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
            }
    }

    // MARK: - Score Color

    private var scoreColor: Color {
        switch score {
        case 0.8...: return .green
        case 0.6..<0.8: return .orange
        default: return .secondary
        }
    }
}

#Preview {
    VStack {
        ScreenCaptureResultView(
            capture: ScreenCaptureSD.sample,
            score: 0.92,
            onDelete: {}
        )
        ScreenCaptureResultView(
            capture: ScreenCaptureSD.sample,
            score: 0.65,
            onDelete: {}
        )
        ScreenCaptureResultView(
            capture: ScreenCaptureSD.sample,
            score: 0.35,
            onDelete: {}
        )
    }
    .padding()
    .frame(width: 500)
}
#endif
