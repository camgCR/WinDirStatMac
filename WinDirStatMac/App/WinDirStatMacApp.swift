// SPDX-License-Identifier: GPL-2.0-or-later
import SwiftUI

extension Notification.Name {
    static let openFolderRequested = Notification.Name("openFolderRequested")
    static let searchRequested = Notification.Name("searchRequested")
    static let exportCSVRequested = Notification.Name("exportCSVRequested")
}

@main
struct WinDirStatMacApp: App {
    @State private var viewModel = ScanViewModel()

    var body: some Scene {
        WindowGroup {
            MainWindowView(viewModel: viewModel)
                .frame(
                    minWidth: 640, idealWidth: 900, maxWidth: .infinity,
                    minHeight: 420, idealHeight: 600, maxHeight: .infinity
                )
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 900, height: 600)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button(loc("Scan Folder…")) {
                    NotificationCenter.default.post(name: .openFolderRequested, object: nil)
                }
                .keyboardShortcut("o", modifiers: .command)
            }
            CommandGroup(after: .textEditing) {
                Button(loc("Search")) {
                    NotificationCenter.default.post(name: .searchRequested, object: nil)
                }
                .keyboardShortcut("f", modifiers: .command)
            }
            CommandGroup(after: .saveItem) {
                Button(loc("Export CSV…")) {
                    NotificationCenter.default.post(name: .exportCSVRequested, object: nil)
                }
                .keyboardShortcut("e", modifiers: .command)
            }
        }

        Settings {
            SettingsView(settings: AppSettings.shared)
        }
    }
}
