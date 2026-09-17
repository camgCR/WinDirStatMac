// SPDX-License-Identifier: GPL-2.0-or-later
import Testing
@testable import DirStatCore

struct TreeMutationTests {
    @Test func removeFromTreeDetachesNodeAndUpdatesAncestorSizes() async throws {
        let fixture = TempDirectoryFixture()
        fixture.makeFile("sub/a.txt", byteCount: 100)
        fixture.makeFile("sub/b.txt", byteCount: 50)

        let tree = await DirectoryScanner().scan(rootPath: fixture.path)
        let rootID = try #require(await tree.rootID)
        let subID = try #require(await firstChild(named: "sub", of: rootID, in: tree))
        let aID = try #require(await firstChild(named: "a.txt", of: subID, in: tree))

        #expect(await tree.node(rootID).aggregateLogical == 150)

        let parent = await tree.removeFromTree(aID)
        #expect(parent == subID)

        let updatedSub = await tree.node(subID)
        #expect(updatedSub.aggregateLogical == 50)
        #expect(!updatedSub.children.contains(aID))

        let updatedRoot = await tree.node(rootID)
        #expect(updatedRoot.aggregateLogical == 50)
    }

    @Test func removeFromTreeOnRootIsANoOp() async {
        let fixture = TempDirectoryFixture()
        fixture.makeFile("a.txt", byteCount: 10)
        let tree = await DirectoryScanner().scan(rootPath: fixture.path)
        let rootID = await tree.rootID!
        let result = await tree.removeFromTree(rootID)
        #expect(result == nil)
    }

    @Test func recordsDeniedPathsFromScan() async {
        let fixture = TempDirectoryFixture()
        fixture.makeFile("visible.txt", byteCount: 1)
        _ = fixture.makeUnreadableDirectory("locked")
        defer { fixture.restorePermissions("locked") }

        let tree = await DirectoryScanner().scan(rootPath: fixture.path)
        let denied = await tree.deniedPaths
        #expect(denied.contains { $0.hasSuffix("/locked") })
    }

    private func firstChild(named name: String, of parent: NodeID, in tree: FileSystemTree) async -> NodeID? {
        let root = await tree.node(parent)
        for childID in root.children {
            let child = await tree.node(childID)
            if child.name == name { return childID }
        }
        return nil
    }
}
