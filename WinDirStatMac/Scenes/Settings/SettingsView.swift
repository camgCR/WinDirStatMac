// SPDX-License-Identifier: GPL-2.0-or-later
import SwiftUI
import DirStatCore

struct SettingsView: View {
    @Bindable var settings: AppSettings

    var body: some View {
        Form {
            Section(loc("Language")) {
                Picker(loc("Language"), selection: $settings.language) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
            }

            Section(loc("Scanning Section")) {
                Toggle(loc("Treat packages (.app, .framework, …) as files"), isOn: $settings.treatPackagesAsFiles)
                Picker(loc("Measure size by"), selection: $settings.sizeMode) {
                    Text(loc("Disk space")).tag(SizeMode.allocated)
                    Text(loc("Logical size")).tag(SizeMode.logical)
                }
                .pickerStyle(.radioGroup)
            }

            Section(loc("Cleanup")) {
                Toggle(loc("Confirm before moving to Trash or deleting"), isOn: $settings.confirmBeforeDelete)
            }

            Section(loc("Treemap")) {
                VStack(alignment: .leading) {
                    Slider(value: $settings.treemapMinTileArea, in: 4...100, step: 1)
                    Text("\(loc("Minimum tile size")): \(Int(settings.treemapMinTileArea)) pt²")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(20)
        .frame(width: 380)
    }
}
