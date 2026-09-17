import Testing
@testable import DirStatCore

struct SizeAggregationTests {
    private func file(parent: NodeID, name: String, size: Int64) -> FileSystemNode {
        FileSystemNode(parent: parent, name: name, sizeLogical: size, sizeAllocated: size)
    }

    private func directory(parent: NodeID?, name: String, children: [NodeID]) -> FileSystemNode {
        FileSystemNode(parent: parent, name: name, isDirectory: true, children: children)
    }

    @Test func rollsUpNestedDirectorySizesBottomUp() {
        // root -> [fileA(10), dirB -> [fileC(5), fileD(7)]]
        let rootID = NodeID(rawValue: 0)
        let fileAID = NodeID(rawValue: 1)
        let dirBID = NodeID(rawValue: 2)
        let fileCID = NodeID(rawValue: 3)
        let fileDID = NodeID(rawValue: 4)

        var nodes: [FileSystemNode] = [
            directory(parent: nil, name: "root", children: [fileAID, dirBID]),
            file(parent: rootID, name: "a", size: 10),
            directory(parent: rootID, name: "b", children: [fileCID, fileDID]),
            file(parent: dirBID, name: "c", size: 5),
            file(parent: dirBID, name: "d", size: 7),
        ]

        SizeAggregator.aggregate(nodes: &nodes, root: rootID)

        #expect(nodes[Int(dirBID.rawValue)].aggregateLogical == 12)
        #expect(nodes[Int(rootID.rawValue)].aggregateLogical == 22)
        #expect(nodes[Int(rootID.rawValue)].aggregateAllocated == 22)
    }

    @Test func emptyDirectoryAggregatesToZero() {
        let rootID = NodeID(rawValue: 0)
        var nodes: [FileSystemNode] = [directory(parent: nil, name: "empty", children: [])]
        SizeAggregator.aggregate(nodes: &nodes, root: rootID)
        #expect(nodes[0].aggregateLogical == 0)
        #expect(nodes[0].aggregateAllocated == 0)
    }

    @Test func logicalAndAllocatedAggregateIndependently() {
        let rootID = NodeID(rawValue: 0)
        let fileAID = NodeID(rawValue: 1)
        let fileBID = NodeID(rawValue: 2)
        var nodes: [FileSystemNode] = [
            directory(parent: nil, name: "root", children: [fileAID, fileBID]),
            FileSystemNode(parent: rootID, name: "a", sizeLogical: 100, sizeAllocated: 4096),
            FileSystemNode(parent: rootID, name: "b", sizeLogical: 200, sizeAllocated: 4096),
        ]
        SizeAggregator.aggregate(nodes: &nodes, root: rootID)
        #expect(nodes[0].aggregateLogical == 300)
        #expect(nodes[0].aggregateAllocated == 8192)
    }
}
