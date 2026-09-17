// SPDX-License-Identifier: GPL-2.0-or-later
import SwiftUI
import AppKit

extension Notification.Name {
    static let openFolderRequested = Notification.Name("openFolderRequested")
    static let searchRequested = Notification.Name("searchRequested")
    static let exportCSVRequested = Notification.Name("exportCSVRequested")
    static let findDuplicatesRequested = Notification.Name("findDuplicatesRequested")
}

/// Launching via `swift run` (a bare command-line process, not via Finder/LaunchServices
/// like a real double-clicked .app) sometimes leaves the app without proper foreground
/// activation: windows and sheets appear, mouse clicks work, but keyboard input isn't
/// reliably routed to the key window's first responder — text fields visually exist but
/// never actually receive typed characters. Explicitly setting a regular activation
/// policy and activating on launch fixes it; a properly packaged/signed .app (see
/// Packaging/build_dmg.sh) shouldn't need this, but it's harmless there either way.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
struct WinDirStatMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
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
                Button(loc("Find Duplicates…")) {
                    NotificationCenter.default.post(name: .findDuplicatesRequested, object: nil)
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])
            }
        }

        Settings {
            SettingsView(settings: AppSettings.shared)
        }
    }
}
