// SPDX-License-Identifier: GPL-2.0-or-later
import SwiftUI
import AppKit

/// Shown after a scan when some locations couldn't be read — almost always
/// because the app hasn't been granted Full Disk Access. macOS has no
/// programmatic prompt for this (unlike Camera/Contacts), so the best an app can
/// do is detect it after the fact and point the user at System Settings.
struct FullDiskAccessBanner: View {
    let deniedPathCount: Int
    let onRescan: () -> Void
    @State private var dismissed = false

    var body: some View {
        if !dismissed {
            HStack(spacing: 10) {
                Image(systemName: "lock.shield")
                    .foregroundStyle(.orange)
                Text(message)
                    .font(.callout)
                Spacer()
                Button(loc("Open System Settings"), action: openPrivacySettings)
                Button(loc("Rescan"), action: onRescan)
                Button {
                    dismissed = true
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
            }
            .padding(10)
            .background(Color.orange.opacity(0.12))
        }
    }

    private var message: String {
        let template = deniedPathCount == 1
            ? "%d location couldn't be read. WinDirStatMac needs Full Disk Access to see it."
            : "%d locations couldn't be read. WinDirStatMac needs Full Disk Access to see them."
        return String(format: loc(template), deniedPathCount)
    }

    private func openPrivacySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") else { return }
        NSWorkspace.shared.open(url)
    }
}
