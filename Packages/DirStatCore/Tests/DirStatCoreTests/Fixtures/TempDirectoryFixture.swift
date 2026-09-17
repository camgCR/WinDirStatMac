// SPDX-License-Identifier: GPL-2.0-or-later
import Foundation

/// Builds a real temp directory tree for the scanner to walk, and removes it when
/// the test finishes. Using real files (not mocks) exercises the actual POSIX
/// enumeration/stat path, which is the point of testing `DirectoryScanner` at all.
final class TempDirectoryFixture {
    let rootURL: URL

    init() {
        rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("DirStatCoreTests-\(UUID().uuidString)", isDirectory: true)
        try! FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: rootURL)
    }

    var path: String { rootURL.path }

    @discardableResult
    func makeDirectory(_ relativePath: String) -> URL {
        let url = rootURL.appendingPathComponent(relativePath, isDirectory: true)
        try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @discardableResult
    func makeFile(_ relativePath: String, byteCount: Int) -> URL {
        let url = rootURL.appendingPathComponent(relativePath, isDirectory: false)
        try! FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = Data(repeating: 0x41, count: byteCount)
        try! data.write(to: url)
        return url
    }

    @discardableResult
    func makeSymlink(_ relativePath: String, pointingTo targetRelativePath: String) -> URL {
        let url = rootURL.appendingPathComponent(relativePath, isDirectory: false)
        try! FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let targetURL = rootURL.appendingPathComponent(targetRelativePath)
        try! FileManager.default.createSymbolicLink(at: url, withDestinationURL: targetURL)
        return url
    }

    @discardableResult
    func makeHardLink(_ relativePath: String, to targetRelativePath: String) -> URL {
        let url = rootURL.appendingPathComponent(relativePath, isDirectory: false)
        try! FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let targetURL = rootURL.appendingPathComponent(targetRelativePath)
        try! FileManager.default.linkItem(at: targetURL, to: url)
        return url
    }

    func makeUnreadableDirectory(_ relativePath: String) -> URL {
        let url = makeDirectory(relativePath)
        try! FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: url.path)
        return url
    }

    func restorePermissions(_ relativePath: String) {
        let url = rootURL.appendingPathComponent(relativePath, isDirectory: true)
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
    }
}
