// SPDX-License-Identifier: GPL-2.0-or-later
/// Fast, I/O-free package/bundle detection by extension. Deliberately not using
/// `NSWorkspace.shared.isFilePackage(atPath:)` (which stats the directory and can
/// consult its Info.plist) as the primary check — calling that across hundreds of
/// thousands of ordinary folders during a scan would be needlessly expensive. This
/// covers the extensions that matter in practice, matching Finder's own behavior
/// for the common cases.
public enum BundleDetection {
    private static let packageExtensions: Set<String> = [
        "app", "bundle", "framework", "plugin", "kext", "prefpane", "qlgenerator",
        "component", "docset", "playground", "xcodeproj", "xcworkspace", "xcassets",
        "scptd", "saver", "mdimporter", "appex", "systemextension", "driverextension",
        "photoslibrary", "musiclibrary", "theater", "lpdc", "sparkle_guided",
    ]

    public static func isKnownPackageExtension(_ ext: String) -> Bool {
        packageExtensions.contains(ext.lowercased())
    }
}
