// SPDX-License-Identifier: GPL-2.0-or-later
import Testing
@testable import DirStatCore

struct ScannerTests {
    @Test func scansNestedFilesAndComputesSizes() async throws {
        let fixture = TempDirectoryFixture()
        fixture.makeFile("a.txt", byteCount: 100)
        fixture.makeFile("sub/b.txt", byteCount: 200)
        fixture.makeFile("sub/deeper/c.txt", byteCount: 50)

        let tree = await DirectoryScanner().scan(rootPath: fixture.path)
        let rootID = await tree.rootID!
        let root = await tree.node(rootID)

        #expect(root.aggregateLogical == 350)
        #expect(root.children.count == 2) // a.txt, sub/

        let sub = try #require(await firstChild(named: "sub", of: rootID, in: tree))
        #expect(sub.isDirectory)
        #expect(sub.aggregateLogical == 250)
    }

    @Test func doesNotFollowSymlinksButRecordsThem() async throws {
        let fixture = TempDirectoryFixture()
        fixture.makeFile("real.txt", byteCount: 1000)
        fixture.makeDirectory("realdir")
        fixture.makeFile("realdir/inner.txt", byteCount: 500)
        fixture.makeSymlink("link-to-file", pointingTo: "real.txt")
        fixture.makeSymlink("link-to-dir", pointingTo: "realdir")

        let tree = await DirectoryScanner().scan(rootPath: fixture.path)
        let rootID = await tree.rootID!

        let linkToDir = try #require(await firstChild(named: "link-to-dir", of: rootID, in: tree))
        #expect(linkToDir.isSymlink)
        #expect(linkToDir.children.isEmpty) // never traversed into the target

        let root = await tree.node(rootID)
        // real.txt (1000) + realdir/inner.txt (500) + two symlink entries (their own small size) — symlinks must not double-count the target's bytes.
        #expect(root.aggregateLogical < 1000 + 500 + 1000 + 500)
    }

    @Test func marksUnreadableDirectoriesWithoutCrashing() async throws {
        let fixture = TempDirectoryFixture()
        fixture.makeFile("visible.txt", byteCount: 10)
        _ = fixture.makeUnreadableDirectory("locked")
        defer { fixture.restorePermissions("locked") }

        let tree = await DirectoryScanner().scan(rootPath: fixture.path)
        let rootID = await tree.rootID!

        let locked = try #require(await firstChild(named: "locked", of: rootID, in: tree))
        #expect(locked.permissionDenied)
        #expect(locked.children.isEmpty)

        let visible = try #require(await firstChild(named: "visible.txt", of: rootID, in: tree))
        #expect(!visible.permissionDenied)
        #expect(visible.sizeLogical == 10)
    }

    @Test func treatsKnownPackageExtensionsAsOpaqueLeavesByDefault() async throws {
        let fixture = TempDirectoryFixture()
        fixture.makeFile("MyApp.app/Contents/MacOS/MyApp", byteCount: 4000)
        fixture.makeFile("MyApp.app/Contents/Resources/icon.icns", byteCount: 1000)

        let tree = await DirectoryScanner().scan(rootPath: fixture.path)
        let rootID = await tree.rootID!

        let bundle = try #require(await firstChild(named: "MyApp.app", of: rootID, in: tree))
        #expect(bundle.isPackage)
        #expect(bundle.children.isEmpty)
        #expect(bundle.aggregateLogical == 5000)
    }

    @Test func expandsPackagesWhenOptedOut() async throws {
        let fixture = TempDirectoryFixture()
        fixture.makeFile("MyApp.app/Contents/MacOS/MyApp", byteCount: 4000)

        let scanner = DirectoryScanner(options: ScanOptions(treatPackagesAsFiles: false))
        let tree = await scanner.scan(rootPath: fixture.path)
        let rootID = await tree.rootID!

        let bundle = try #require(await firstChild(named: "MyApp.app", of: rootID, in: tree))
        #expect(!bundle.isPackage)
        #expect(!bundle.children.isEmpty)
    }

    @Test func cancellationLeavesAPartialButConsistentTree() async throws {
        let fixture = TempDirectoryFixture()
        for i in 0..<20 {
            fixture.makeFile("dir\(i)/file.txt", byteCount: 10)
        }

        let task = Task { await DirectoryScanner().scan(rootPath: fixture.path) }
        task.cancel()
        let tree = await task.value
        let rootID = await tree.rootID!
        let root = await tree.node(rootID)
        // Cancellation is cooperative and best-effort here; the important invariant
        // is that we get back a well-formed tree, not a crash or an infinite hang.
        #expect(root.aggregateLogical >= 0)
    }

    private func firstChild(named name: String, of parent: NodeID, in tree: FileSystemTree) async -> FileSystemNode? {
        let root = await tree.node(parent)
        for childID in root.children {
            let child = await tree.node(childID)
            if child.name == name { return child }
        }
        return nil
    }
}
