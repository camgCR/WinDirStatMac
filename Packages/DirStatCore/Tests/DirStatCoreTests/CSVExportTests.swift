// SPDX-License-Identifier: GPL-2.0-or-later
import Testing
@testable import DirStatCore

struct CSVExportTests {
    @Test func exportsOneRowPerNodeWithRelativePaths() async throws {
        let fixture = TempDirectoryFixture()
        fixture.makeFile("a.txt", byteCount: 10)
        fixture.makeFile("sub/b.txt", byteCount: 20)

        let tree = await DirectoryScanner().scan(rootPath: fixture.path)
        let rows = await tree.exportRows()

        let byPath = Dictionary(uniqueKeysWithValues: rows.map { ($0.path, $0) })
        let rootID = try #require(await tree.rootID)
        let rootName = await tree.node(rootID).name

        #expect(byPath[rootName]?.type == .directory)
        #expect(byPath["\(rootName)/a.txt"]?.type == .file)
        #expect(byPath["\(rootName)/a.txt"]?.sizeLogical == 10)
        #expect(byPath["\(rootName)/sub"]?.type == .directory)
        #expect(byPath["\(rootName)/sub/b.txt"]?.sizeLogical == 20)
    }

    @Test func excludesDeletedNodes() async throws {
        let fixture = TempDirectoryFixture()
        fixture.makeFile("keep.txt", byteCount: 5)
        fixture.makeFile("gone.txt", byteCount: 5)

        let tree = await DirectoryScanner().scan(rootPath: fixture.path)
        let rootID = try #require(await tree.rootID)
        let root = await tree.node(rootID)
        let goneID = try #require(await withChild(named: "gone.txt", of: root, in: tree))

        _ = await tree.removeFromTree(goneID)
        let rows = await tree.exportRows()
        #expect(!rows.contains { $0.name == "gone.txt" })
        #expect(rows.contains { $0.name == "keep.txt" })
    }

    private func withChild(named name: String, of node: FileSystemNode, in tree: FileSystemTree) async -> NodeID? {
        for childID in node.children {
            if await tree.node(childID).name == name { return childID }
        }
        return nil
    }
}

struct CSVFormatterTests {
    @Test func escapesCommasQuotesAndNewlines() {
        let rows = [
            CSVRow(path: "a, b.txt", name: "a, b.txt", type: .file, sizeLogical: 1, sizeAllocated: 1, extensionName: "txt"),
            CSVRow(path: "quote\".txt", name: "quote\".txt", type: .file, sizeLogical: 2, sizeAllocated: 2, extensionName: nil),
        ]
        let csv = CSVFormatter.format(rows: rows)
        #expect(csv.contains("\"a, b.txt\""))
        #expect(csv.contains("\"quote\"\".txt\""))
    }

    @Test func headerIsFirstLine() {
        let csv = CSVFormatter.format(rows: [])
        #expect(csv.hasPrefix("Path,Name,Type,Size (logical),Size (on disk),Extension"))
    }

    @Test func plainFieldsAreNotQuoted() {
        let rows = [CSVRow(path: "a/b.txt", name: "b.txt", type: .file, sizeLogical: 100, sizeAllocated: 4096, extensionName: "txt")]
        let csv = CSVFormatter.format(rows: rows)
        #expect(csv.contains("a/b.txt,b.txt,file,100,4096,txt"))
    }
}
