// SPDX-License-Identifier: GPL-2.0-or-later
import Foundation

enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case english = "en"
    case spanish = "es"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english: return "English"
        case .spanish: return "Español"
        }
    }

    /// Best guess at the user's preferred language the first time the app runs
    /// (before they've made an explicit choice in Settings), from the system's
    /// own language preference.
    static var systemDefault: AppLanguage {
        Locale.preferredLanguages.first?.hasPrefix("es") == true ? .spanish : .english
    }
}

/// English UI text is the source of truth (and the dictionary key below) —
/// `loc(_:)` looks up a Spanish translation when the app's language is set to
/// Spanish, falling back to the English text itself if a key is ever missing.
/// This is a small hand-rolled table rather than a full String Catalog because
/// the app ships as a bare SwiftPM executable (no .xcodeproj / app bundle yet)
/// for this stage of development — see README.md.
private let spanishTranslations: [String: String] = [
    "Scan Folder…": "Escanear carpeta…",
    "Scan": "Escanear",
    "Open": "Abrir",
    "Reveal in Finder": "Revelar en Finder",
    "Move to Trash": "Mover a la Papelera",
    "Delete…": "Eliminar…",
    "Move this item to the Trash?": "¿Mover este elemento a la Papelera?",
    "You can restore it from the Trash.": "Podrás recuperarlo desde la Papelera.",
    "Permanently delete this item?": "¿Eliminar este elemento permanentemente?",
    "This action cannot be undone.": "Esta acción no se puede deshacer.",
    "Continue": "Continuar",
    "Cancel": "Cancelar",
    "Couldn't complete the action": "No se pudo completar la acción",
    "OK": "OK",
    "Name": "Nombre",
    "Size": "Tamaño",
    "On Disk": "En disco",
    "Logical": "Lógico",
    "Extensions": "Extensiones",
    "No Folder Scanned": "Ninguna carpeta escaneada",
    "Choose a folder to see its contents by size.": "Elige una carpeta para ver su contenido por tamaño.",
    "Ready": "Listo",
    "Scan complete": "Escaneo completo",
    "Type": "Tipo",
    "Files": "Archivos",
    "(no extension)": "(sin extensión)",
    "Scanning": "Escaneando",

    // Settings
    "Scanning Section": "Escaneo",
    "Treat packages (.app, .framework, …) as files": "Tratar paquetes (.app, .framework, …) como archivos",
    "Measure size by": "Medir tamaño por",
    "Disk space": "Espacio en disco",
    "Logical size": "Tamaño lógico",
    "Cleanup": "Limpieza",
    "Confirm before moving to Trash or deleting": "Confirmar antes de mover a la Papelera o eliminar",
    "Treemap": "Treemap",
    "Minimum tile size": "Tamaño mínimo de celda",
    "Language": "Idioma",

    // Full Disk Access banner
    "%d location couldn't be read. WinDirStatMac needs Full Disk Access to see it.":
        "%d ubicación no se pudo leer. WinDirStatMac necesita Acceso completo al disco para verla.",
    "%d locations couldn't be read. WinDirStatMac needs Full Disk Access to see them.":
        "%d ubicaciones no se pudieron leer. WinDirStatMac necesita Acceso completo al disco para verlas.",
    "Open System Settings": "Abrir Preferencias del Sistema",
    "Rescan": "Reescanear",

    // Search
    "Search": "Buscar",
    "Search files and folders…": "Buscar archivos y carpetas…",
    "Search this scan": "Buscar en este escaneo",
    "Close": "Cerrar",
    "Export CSV…": "Exportar CSV…",

    // Duplicates
    "Find Duplicates…": "Buscar duplicados…",
    "Duplicate Files": "Archivos duplicados",
    "Hashing files to find duplicates…": "Calculando hashes para encontrar duplicados…",
    "No Duplicates Found": "No se encontraron duplicados",
    "groups": "grupos",
    "could free up": "podrías liberar",
    "Done": "Listo",
    "Looking for same-size files…": "Buscando archivos del mismo tamaño…",
    "Quick filter": "Filtro rápido",
    "Confirming matches": "Confirmando coincidencias",
    "files analyzed": "archivos analizados",
]

@MainActor
func loc(_ english: String) -> String {
    guard AppSettings.shared.language == .spanish else { return english }
    return spanishTranslations[english] ?? english
}

/// For the one status-bar string with an interpolated value, where simple key
/// lookup doesn't fit — kept as its own function rather than stretching
/// `loc(_:)` into a general-purpose format-string engine for a single caller.
/// Deliberately omits a running byte total: it's the live, in-progress sum of
/// `st_size` across files seen so far, not yet corrected for hard links or
/// mount-point boundaries, so showing it mid-scan reads as alarming/wrong
/// (e.g. briefly exceeding the volume's real capacity) even though the
/// *final* total (after DirectoryScanner.scan finishes and hands back the
/// aggregated tree) is correct.
@MainActor
func locScanningStatus(itemCount: Int) -> String {
    AppSettings.shared.language == .spanish
        ? "Escaneando… \(itemCount) elementos"
        : "Scanning… \(itemCount) items"
}
