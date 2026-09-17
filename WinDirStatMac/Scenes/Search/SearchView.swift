// SPDX-License-Identifier: GPL-2.0-or-later
import SwiftUI
import DirStatCore

struct SearchView: View {
    var viewModel: ScanViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [SearchResult] = []
    @State private var isSearching = false
    @FocusState private var fieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField(loc("Search files and folders…"), text: $query)
                    .textFieldStyle(.plain)
                    .focused($fieldFocused)
                if isSearching {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .padding(12)
            Divider()

            if query.trimmingCharacters(in: .whitespaces).isEmpty {
                ContentUnavailableView(loc("Search this scan"), systemImage: "magnifyingglass")
            } else if results.isEmpty && !isSearching {
                ContentUnavailableView.search(text: query)
            } else {
                List(results) { result in
                    SearchResultRow(result: result, viewModel: viewModel) {
                        Task {
                            await viewModel.revealSearchResult(result)
                            dismiss()
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .frame(width: 560, height: 440)
        .onAppear { fieldFocused = true }
        .task(id: query) {
            let currentQuery = query
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            isSearching = true
            let found = await viewModel.search(query: currentQuery)
            guard !Task.isCancelled else { return }
            results = found
            isSearching = false
        }
    }
}

private struct SearchResultRow: View {
    let result: SearchResult
    var viewModel: ScanViewModel
    let onReveal: () -> Void
    @State private var path: String?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: result.isPackage ? "shippingbox" : (result.isDirectory ? "folder" : "doc"))
                .foregroundStyle(.secondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(result.name)
                    .lineLimit(1)
                if let path {
                    Text(path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            Spacer()
            Text(ByteCountFormatter.string(
                fromByteCount: viewModel.sizeMode == .logical ? result.aggregateLogical : result.aggregateAllocated,
                countStyle: .file
            ))
            .foregroundStyle(.secondary)
            Button(action: onReveal) {
                Image(systemName: "arrow.right.circle")
            }
            .buttonStyle(.plain)
            .help(loc("Reveal in Finder"))
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2, perform: onReveal)
        .task {
            path = await viewModel.fullPath(of: result.id)
        }
    }
}
