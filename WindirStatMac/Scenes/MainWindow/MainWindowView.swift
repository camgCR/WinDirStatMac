import SwiftUI
import AppKit
import DirStatCore

struct MainWindowView: View {
    var viewModel: ScanViewModel

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            content
            Divider()
            statusBar
        }
    }

    private var toolbar: some View {
        HStack {
            Button("Escanear carpeta…", action: chooseFolder)
            if let path = viewModel.scannedPath {
                Text(path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Picker("Tamaño", selection: Binding(get: { viewModel.sizeMode }, set: { viewModel.sizeMode = $0 })) {
                Text("En disco").tag(SizeMode.allocated)
                Text("Lógico").tag(SizeMode.logical)
            }
            .pickerStyle(.segmented)
            .frame(width: 220)
        }
        .padding(8)
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.rootID != nil {
            FileTreeOutlineView(viewModel: viewModel)
        } else {
            ContentUnavailableView(
                "Ninguna carpeta escaneada",
                systemImage: "internaldrive",
                description: Text("Elige una carpeta para ver su contenido por tamaño.")
            )
        }
    }

    private var statusBar: some View {
        HStack {
            switch viewModel.scanState {
            case .idle:
                Text("Listo")
            case .scanning(let progress):
                ProgressView()
                    .controlSize(.small)
                Text("Escaneando… \(progress.filesScanned) elementos, \(ByteCountFormatter.string(fromByteCount: progress.bytesScanned, countStyle: .file))")
            case .completed:
                Text("Escaneo completo")
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
        panel.prompt = "Escanear"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        viewModel.startScan(path: url.path)
    }
}
