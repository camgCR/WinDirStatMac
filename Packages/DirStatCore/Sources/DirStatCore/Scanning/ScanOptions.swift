// SPDX-License-Identifier: GPL-2.0-or-later
import Foundation

public struct ScanOptions: Sendable {
    /// When true (the default, matching Finder), directories recognized as macOS
    /// bundles (.app, .framework, ...) are scanned for their total size but exposed
    /// as opaque leaf nodes rather than expandable directories.
    public var treatPackagesAsFiles: Bool

    /// Caps the number of concurrent directory-scan tasks. Defaults to the number
    /// of active cores.
    public var maxConcurrency: Int

    public init(treatPackagesAsFiles: Bool = true, maxConcurrency: Int = ProcessInfo.processInfo.activeProcessorCount) {
        self.treatPackagesAsFiles = treatPackagesAsFiles
        self.maxConcurrency = max(1, maxConcurrency)
    }
}
