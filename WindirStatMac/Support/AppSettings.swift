import Foundation
import Observation
import DirStatCore

/// Persisted app preferences, backed by `UserDefaults` directly rather than
/// `@AppStorage` (which only works declared inside a `View`) since these values
/// are also read from `ScanViewModel` and `TreemapCoordinator`, not just from the
/// Settings screen itself.
@MainActor
@Observable
final class AppSettings {
    static let shared = AppSettings()

    private enum Keys {
        static let treatPackagesAsFiles = "treatPackagesAsFiles"
        static let sizeMode = "sizeMode"
        static let treemapMinTileArea = "treemapMinTileArea"
        static let confirmBeforeDelete = "confirmBeforeDelete"
    }

    var treatPackagesAsFiles: Bool {
        didSet { UserDefaults.standard.set(treatPackagesAsFiles, forKey: Keys.treatPackagesAsFiles) }
    }

    var sizeMode: SizeMode {
        didSet { UserDefaults.standard.set(sizeMode == .logical ? "logical" : "allocated", forKey: Keys.sizeMode) }
    }

    var treemapMinTileArea: Double {
        didSet { UserDefaults.standard.set(treemapMinTileArea, forKey: Keys.treemapMinTileArea) }
    }

    /// Whether "Move to Trash" and "Delete Permanently" ask for confirmation first.
    /// Trash is recoverable either way; this mainly guards against fat-fingering a
    /// permanent delete.
    var confirmBeforeDelete: Bool {
        didSet { UserDefaults.standard.set(confirmBeforeDelete, forKey: Keys.confirmBeforeDelete) }
    }

    private init() {
        let defaults = UserDefaults.standard
        defaults.register(defaults: [
            Keys.treatPackagesAsFiles: true,
            Keys.sizeMode: "allocated",
            Keys.treemapMinTileArea: 12.0,
            Keys.confirmBeforeDelete: true,
        ])
        treatPackagesAsFiles = defaults.bool(forKey: Keys.treatPackagesAsFiles)
        sizeMode = defaults.string(forKey: Keys.sizeMode) == "logical" ? .logical : .allocated
        treemapMinTileArea = defaults.double(forKey: Keys.treemapMinTileArea)
        confirmBeforeDelete = defaults.bool(forKey: Keys.confirmBeforeDelete)
    }
}
