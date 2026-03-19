//
//  DejaViewSearchView.swift
//  Re-Enchanted
//
//  Search interface for DejaView screen captures using semantic and text search.
//

import SwiftUI

struct DejaViewSearchView: View {
    @State private var dejaViewStore = DejaViewStore.shared
    @State private var query = ""
    @State private var timeFilter = ""
    @State private var isSearching = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Text("DejaView Search")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top, 12)

            Text("Search your screen capture history using natural language queries.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.top, 4)
                .padding(.bottom, 8)

            // Search Controls
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search captures...", text: $query)
                        .textFieldStyle(.plain)
                        .onSubmit { performSearch() }
                }
                .padding(8)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)

                HStack {
                    Image(systemName: "clock")
                        .foregroundStyle(.secondary)
                    TextField("e.g., yesterday, last 2 hours", text: $timeFilter)
                        .textFieldStyle(.plain)
                        .onSubmit { performSearch() }
                }
                .padding(8)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)

                Button(action: performSearch) {
                    HStack {
                        if isSearching {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text("Search")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(query.isEmpty || isSearching)
            }
            .padding(.horizontal)
            .padding(.bottom, 12)

            Divider()

            // Results
            if dejaViewStore.searchResults.isEmpty && !isSearching {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No results")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Enter a search query to find screen captures")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(Array(dejaViewStore.searchResults.enumerated()), id: \.offset) { _, result in
                            ScreenCaptureResultView(
                                capture: result.capture,
                                score: result.score,
                                onDelete: {
                                    Task { await dejaViewStore.deleteCapture(result.capture) }
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
            }

            Spacer(minLength: 0)
        }
    }

    private func performSearch() {
        guard !query.isEmpty else { return }
        isSearching = true
        Task {
            await dejaViewStore.search(
                query: query,
                timeFilter: timeFilter.isEmpty ? nil : timeFilter
            )
            isSearching = false
        }
    }
}

#Preview {
    DejaViewSearchView()
        .frame(width: 500, height: 600)
}
