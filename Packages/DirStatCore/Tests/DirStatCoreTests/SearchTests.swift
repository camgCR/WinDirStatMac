// SPDX-License-Identifier: GPL-2.0-or-later
import Testing
@testable import DirStatCore

struct SearchTests {
    @Test func findsMatchesCaseInsensitively() async throws {
        let fixture = TempDirectoryFixture()
        fixture.makeFile("Report.PDF", byteCount: 100)
        fixture.makeFile("sub/report_final.pdf", byteCount: 200)
        fixture.makeFile("sub/notes.txt", byteCount: 10)

        let tree = await DirectoryScanner().scan(rootPath: fixture.path)
        let results = await tree.search(query: "report", sizeMode: .logical)

        #expect(results.count == 2)
        #expect(results.allSatisfy { $0.name.lowercased().contains("report") })
    }

    @Test func sortsResultsBySizeDescending() async throws {
        let fixture = TempDirectoryFixture()
        fixture.makeFile("small_x.bin", byteCount: 10)
        fixture.makeFile("big_x.bin", byteCount: 10_000)

        let tree = await DirectoryScanner().scan(rootPath: fixture.path)
        let results = await tree.search(query: "_x", sizeMode: .logical)

        #expect(results.map(\.name) == ["big_x.bin", "small_x.bin"])
    }

    @Test func emptyQueryReturnsNoResults() async throws {
        let fixture = TempDirectoryFixture()
        fixture.makeFile("a.txt", byteCount: 10)
        let tree = await DirectoryScanner().scan(rootPath: fixture.path)
        let results = await tree.search(query: "   ", sizeMode: .logical)
        #expect(results.isEmpty)
    }

    @Test func excludesDeletedNodes() async throws {
        let fixture = TempDirectoryFixture()
        fixture.makeFile("deleteme.txt", byteCount: 10)

        let tree = await DirectoryScanner().scan(rootPath: fixture.path)
        let rootID = try #require(await tree.rootID)
        let root = await tree.node(rootID)
        let targetID = try #require(root.children.first)

        _ = await tree.removeFromTree(targetID)
        let results = await tree.search(query: "deleteme", sizeMode: .logical)
        #expect(results.isEmpty)
    }
}
