// SPDX-License-Identifier: GPL-2.0-or-later
import Foundation
import Testing
@testable import DirStatCore

/// Verifies the scanner doesn't cross filesystem boundaries — the fix for a real
/// bug where scanning "/" could report *more* bytes than the physical disk's
/// capacity, because sibling APFS volumes in the same container (and other
/// mounted volumes/disk images/network shares nested under the scan root) share
/// underlying storage, so descending into them double-counts real usage.
///
/// This attaches an actual small disk image at a custom mount point inside a temp
/// fixture — the only way to reliably get a real device-id boundary to scan
/// across — and skips itself if `hdiutil` isn't usable in this environment rather
/// than failing the whole suite over an environment limitation unrelated to the
/// code under test.
struct MountPointTests {
    @Test func doesNotDescendIntoOrDoubleCountAMountedVolume() async throws {
        let fixture = TempDirectoryFixture()
        fixture.makeFile("outside.txt", byteCount: 1000)
        let mountPath = fixture.rootURL.appendingPathComponent("mounted", isDirectory: true).path
        try FileManager.default.createDirectory(atPath: mountPath, withIntermediateDirectories: true)

        guard let diskImage = try? attachRAMDisk(atMountPoint: mountPath, megabytes: 4) else {
            // Can't create/attach a disk image in this environment (e.g. a locked-down
            // sandbox) — not something this test can control, so skip rather than fail.
            return
        }
        defer { detach(diskImage) }

        let innerFileURL = URL(fileURLWithPath: mountPath).appendingPathComponent("inside.txt")
        try Data(repeating: 0x42, count: 2000).write(to: innerFileURL)

        let tree = await DirectoryScanner().scan(rootPath: fixture.path)
        let rootID = try #require(await tree.rootID)
        let root = await tree.node(rootID)

        let mountedID = try #require(await firstChild(named: "mounted", of: rootID, in: tree))
        let mounted = await tree.node(mountedID)

        #expect(mounted.isMountPoint)
        #expect(mounted.children.isEmpty) // never descended into it

        // The mount point itself contributes a little (the mounted volume's own
        // root-directory metadata — e.g. HFS+ reports a small nonzero size for an
        // empty root), but "inside.txt" (2000 bytes) must never be added to the
        // root's total — that's the actual double-counting bug this guards against.
        #expect(root.aggregateLogical >= 1000)
        #expect(root.aggregateLogical < 1000 + 2000)
    }

    private func firstChild(named name: String, of parent: NodeID, in tree: FileSystemTree) async -> NodeID? {
        let node = await tree.node(parent)
        for childID in node.children {
            let child = await tree.node(childID)
            if child.name == name { return childID }
        }
        return nil
    }

    private func attachRAMDisk(atMountPoint mountPoint: String, megabytes: Int) throws -> String {
        let sectors = megabytes * 2048 // 512-byte sectors
        let attach = Process()
        attach.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        attach.arguments = ["attach", "-nomount", "ram://\(sectors)"]
        let outPipe = Pipe()
        attach.standardOutput = outPipe
        attach.standardError = Pipe()
        try attach.run()
        attach.waitUntilExit()
        guard attach.terminationStatus == 0 else { throw CocoaError(.featureUnsupported) }
        let output = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        guard let devicePath = output.split(separator: "\n").first.map(String.init)?.trimmingCharacters(in: .whitespaces) else {
            throw CocoaError(.featureUnsupported)
        }

        let format = Process()
        format.executableURL = URL(fileURLWithPath: "/sbin/newfs_hfs")
        format.arguments = [devicePath]
        format.standardOutput = Pipe()
        format.standardError = Pipe()
        try format.run()
        format.waitUntilExit()
        guard format.terminationStatus == 0 else {
            detach(devicePath)
            throw CocoaError(.featureUnsupported)
        }

        let mount = Process()
        mount.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        mount.arguments = ["mount", "-mountPoint", mountPoint, devicePath]
        mount.standardOutput = Pipe()
        mount.standardError = Pipe()
        try mount.run()
        mount.waitUntilExit()
        guard mount.terminationStatus == 0 else {
            detach(devicePath)
            throw CocoaError(.featureUnsupported)
        }

        return devicePath
    }

    private func detach(_ devicePath: String) {
        let detach = Process()
        detach.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        detach.arguments = ["detach", devicePath, "-force"]
        detach.standardOutput = Pipe()
        detach.standardError = Pipe()
        try? detach.run()
        detach.waitUntilExit()
    }
}
