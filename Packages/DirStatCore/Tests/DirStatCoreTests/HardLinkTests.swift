// SPDX-License-Identifier: GPL-2.0-or-later
import Testing
@testable import DirStatCore

/// A hard-linked file is the exact same bytes reachable from multiple paths.
/// Counting each link's full size would report more bytes than the volume
/// actually holds — a real bug this guards against (macOS system volumes, and
/// Xcode/CoreSimulator installs especially, use hard links heavily).
struct HardLinkTests {
    @Test func countsAHardLinkedFileOnlyOnce() async throws {
        let fixture = TempDirectoryFixture()
        fixture.makeFile("original.bin", byteCount: 10_000)
        fixture.makeHardLink("sub/linked.bin", to: "original.bin")

        let tree = await DirectoryScanner().scan(rootPath: fixture.path)
        let rootID = try #require(await tree.rootID)
        let root = await tree.node(rootID)

        // Both directory entries point at the same 10,000-byte inode — the total
        // must reflect that data once, not twice (20,000).
        #expect(root.aggregateLogical == 10_000)
    }

    @Test func hardLinkedFileStillAppearsInTheTree() async throws {
        let fixture = TempDirectoryFixture()
        fixture.makeFile("original.bin", byteCount: 500)
        fixture.makeHardLink("linked.bin", to: "original.bin")

        let tree = await DirectoryScanner().scan(rootPath: fixture.path)
        let rootID = try #require(await tree.rootID)
        let root = await tree.node(rootID)

        var names: Set<String> = []
        for childID in root.children {
            names.insert(await tree.node(childID).name)
        }
        // Both names are still listed — only the *second* one's contribution to
        // the total is zeroed, it isn't hidden from the tree.
        #expect(names == ["original.bin", "linked.bin"])
    }

    @Test func ordinaryFilesWithoutExtraLinksAreUnaffected() async throws {
        let fixture = TempDirectoryFixture()
        fixture.makeFile("a.txt", byteCount: 100)
        fixture.makeFile("b.txt", byteCount: 200)

        let tree = await DirectoryScanner().scan(rootPath: fixture.path)
        let rootID = try #require(await tree.rootID)
        let root = await tree.node(rootID)
        #expect(root.aggregateLogical == 300)
    }
}
