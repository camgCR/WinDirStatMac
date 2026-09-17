import SwiftUI

extension Notification.Name {
    static let openFolderRequested = Notification.Name("openFolderRequested")
}

@main
struct WindirStatMacApp: App {
    @State private var viewModel = ScanViewModel()

    var body: some Scene {
        WindowGroup {
            MainWindowView(viewModel: viewModel)
                .frame(minWidth: 640, minHeight: 420)
        }
        .defaultSize(width: 900, height: 600)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Escanear carpeta…") {
                    NotificationCenter.default.post(name: .openFolderRequested, object: nil)
                }
                .keyboardShortcut("o", modifiers: .command)
            }
        }

        Settings {
            SettingsView(settings: AppSettings.shared)
        }
    }
}
