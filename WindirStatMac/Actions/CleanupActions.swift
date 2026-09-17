// SPDX-License-Identifier: GPL-2.0-or-later
import AppKit

enum CleanupActionError: LocalizedError {
    case underlying(Error)

    var errorDescription: String? {
        switch self {
        case .underlying(let error): error.localizedDescription
        }
    }
}

/// Thin wrappers over the real filesystem/Finder operations a cleanup action
/// performs. Kept separate from `ScanViewModel` so the actual side effects (which
/// touch real files) are easy to spot in review.
@MainActor
enum CleanupActions {
    static func revealInFinder(path: String) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    static func openWithDefaultApplication(path: String) {
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    /// Moves `path` to the Trash (recoverable), matching Finder's own delete.
    static func moveToTrash(path: String) throws {
        do {
            var trashedURL: NSURL?
            try FileManager.default.trashItem(at: URL(fileURLWithPath: path), resultingItemURL: &trashedURL)
        } catch {
            throw CleanupActionError.underlying(error)
        }
    }

    /// Permanently deletes `path` — not recoverable. Callers are expected to have
    /// already confirmed this with the user.
    static func deletePermanently(path: String) throws {
        do {
            try FileManager.default.removeItem(atPath: path)
        } catch {
            throw CleanupActionError.underlying(error)
        }
    }
}
