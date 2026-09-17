// SPDX-License-Identifier: GPL-2.0-or-later
import SwiftUI
import AppKit
import DirStatCore

struct MainWindowView: View {
    var viewModel: ScanViewModel
    @State private var showInspector = true

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.deniedPathCount > 0 {
                FullDiskAccessBanner(deniedPathCount: viewModel.deniedPathCount, onRescan: { viewModel.rescan() })
                Divider()
            }
            content
            Divider()
            statusBar
        }
        .alert(loc("Couldn't complete the action"), isPresented: Binding(
            get: { viewModel.lastErrorMessage != nil },
            set: { if !$0 { viewModel.lastErrorMessage = nil } }
        )) {
            Button(loc("OK"), role: .cancel) {}
        } message: {
            Text(viewModel.lastErrorMessage ?? "")
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(loc("Scan Folder…"), action: chooseFolder)
            }
            ToolbarItem(placement: .principal) {
                if let path = viewModel.scannedPath {
                    Text(path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            ToolbarItem {
                Picker(loc("Size"), selection: Binding(get: { viewModel.sizeMode }, set: { viewModel.sizeMode = $0 })) {
                    Text(loc("On Disk")).tag(SizeMode.allocated)
                    Text(loc("Logical")).tag(SizeMode.logical)
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }
            ToolbarItem {
                Button {
                    showInspector.toggle()
                } label: {
                    Label(loc("Extensions"), systemImage: "sidebar.right")
                }
            }
        }
        .inspector(isPresented: $showInspector) {
            ExtensionListView(viewModel: viewModel)
                .inspectorColumnWidth(min: 220, ideal: 260, max: 360)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openFolderRequested)) { _ in
            chooseFolder()
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.rootID != nil {
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    FileTreeOutlineView(viewModel: viewModel)
                        .frame(height: geometry.size.height * 0.5)
                    Divider()
                    TreemapBreadcrumbView(viewModel: viewModel)
                    Divider()
                    TreemapView(viewModel: viewModel)
                        .frame(height: geometry.size.height * 0.5 - 30)
                    Divider()
                    TreemapInfoBar(viewModel: viewModel)
                }
            }
        } else {
            ContentUnavailableView(
                loc("No Folder Scanned"),
                systemImage: "internaldrive",
                description: Text(loc("Choose a folder to see its contents by size."))
            )
        }
    }

    private var statusBar: some View {
        HStack {
            switch viewModel.scanState {
            case .idle:
                Text(loc("Ready"))
            case .scanning(let progress):
                ProgressView()
                    .controlSize(.small)
                Text(locScanningStatus(itemCount: progress.filesScanned))
            case .completed:
                Text(loc("Scan complete"))
            }
            Spacer()
        }
        .font(.caption)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = loc("Scan")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        viewModel.startScan(path: url.path)
    }
}
