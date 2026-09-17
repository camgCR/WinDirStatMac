// SPDX-License-Identifier: GPL-2.0-or-later
import Testing
@testable import DirStatCore

struct ExtensionAggregationTests {
    @Test func countsAndSumsPerExtension() throws {
        var table = ExtensionTable()
        let txt = table.intern("txt")
        let png = table.intern("png")

        let rootID = NodeID(rawValue: 0)
        let nodes: [FileSystemNode] = [
            FileSystemNode(parent: nil, name: "root", isDirectory: true, children: []),
            FileSystemNode(parent: rootID, name: "a.txt", extensionID: txt, sizeLogical: 10, sizeAllocated: 4096),
            FileSystemNode(parent: rootID, name: "b.txt", extensionID: txt, sizeLogical: 20, sizeAllocated: 4096),
            FileSystemNode(parent: rootID, name: "c.png", extensionID: png, sizeLogical: 300, sizeAllocated: 4096),
        ]

        let stats = ExtensionAggregator.aggregate(nodes: nodes, extensionTable: table)
        let txtStats = try #require(stats.first { $0.name == "txt" })
        let pngStats = try #require(stats.first { $0.name == "png" })

        #expect(txtStats.fileCount == 2)
        #expect(txtStats.totalLogical == 30)
        #expect(txtStats.totalAllocated == 8192)
        #expect(pngStats.fileCount == 1)
        #expect(pngStats.totalLogical == 300)
    }

    @Test func sortsDescendingByAllocatedSize() {
        var table = ExtensionTable()
        let small = table.intern("small")
        let big = table.intern("big")
        let nodes: [FileSystemNode] = [
            FileSystemNode(parent: nil, name: "a.small", extensionID: small, sizeLogical: 1, sizeAllocated: 100),
            FileSystemNode(parent: nil, name: "a.big", extensionID: big, sizeLogical: 1, sizeAllocated: 10_000),
        ]
        let stats = ExtensionAggregator.aggregate(nodes: nodes, extensionTable: table)
        #expect(stats.first?.name == "big")
    }

    @Test func excludesDirectoriesAndPackages() {
        var table = ExtensionTable()
        let ext = table.intern("app")
        let nodes: [FileSystemNode] = [
            FileSystemNode(parent: nil, name: "dir", isDirectory: true),
            FileSystemNode(parent: nil, name: "Bundle.app", extensionID: ext, sizeLogical: 500, isDirectory: true, isPackage: true),
        ]
        let stats = ExtensionAggregator.aggregate(nodes: nodes, extensionTable: table)
        #expect(stats.isEmpty)
    }

    @Test func noExtensionFilesGroupTogether() {
        var table = ExtensionTable()
        _ = table.intern("txt")
        let nodes: [FileSystemNode] = [
            FileSystemNode(parent: nil, name: "README", sizeLogical: 10),
            FileSystemNode(parent: nil, name: ".gitignore", sizeLogical: 5),
        ]
        let stats = ExtensionAggregator.aggregate(nodes: nodes, extensionTable: table)
        #expect(stats.count == 1)
        #expect(stats[0].name == nil)
        #expect(stats[0].fileCount == 2)
    }
}
