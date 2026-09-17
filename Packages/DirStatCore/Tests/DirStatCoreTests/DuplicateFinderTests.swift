// SPDX-License-Identifier: GPL-2.0-or-later
import Foundation
import Testing
@testable import DirStatCore

struct DuplicateFinderTests {
    @Test func findsFilesWithIdenticalContent() async throws {
        let fixture = TempDirectoryFixture()
        fixture.makeFile("a.txt", byteCount: 5000)
        fixture.makeFile("sub/copy_of_a.txt", byteCount: 5000) // same content: TempDirectoryFixture fills with the same byte
        fixture.makeFile("unique.txt", byteCount: 5000 + 1) // different size -> never a candidate

        let tree = await DirectoryScanner().scan(rootPath: fixture.path)
        let groups = await DuplicateFinder.findDuplicates(in: tree)

        #expect(groups.count == 1)
        #expect(groups[0].nodeIDs.count == 2)
        #expect(groups[0].size == 5000)
    }

    @Test func sameSizeDifferentContentIsNotADuplicate() async throws {
        let fixture = TempDirectoryFixture()
        let urlA = fixture.rootURL.appendingPathComponent("a.bin")
        let urlB = fixture.rootURL.appendingPathComponent("b.bin")
        try Data(repeating: 0x41, count: 1000).write(to: urlA)
        try Data(repeating: 0x42, count: 1000).write(to: urlB) // same size, different byte value throughout

        let tree = await DirectoryScanner().scan(rootPath: fixture.path)
        let groups = await DuplicateFinder.findDuplicates(in: tree)
        #expect(groups.isEmpty)
    }

    @Test func filesDifferingOnlyAfterThePartialHashWindowAreStillCaughtByTheFullHash() async throws {
        let fixture = TempDirectoryFixture()
        let urlA = fixture.rootURL.appendingPathComponent("a.bin")
        let urlB = fixture.rootURL.appendingPathComponent("b.bin")
        // Identical first 4KB (the partial-hash window), diverge after that.
        var dataA = Data(repeating: 0x41, count: 8192)
        var dataB = Data(repeating: 0x41, count: 8192)
        dataA[8000] = 0x01
        dataB[8000] = 0x02
        try dataA.write(to: urlA)
        try dataB.write(to: urlB)

        let tree = await DirectoryScanner().scan(rootPath: fixture.path)
        let groups = await DuplicateFinder.findDuplicates(in: tree)
        #expect(groups.isEmpty)
    }

    @Test func groupsMoreThanTwoIdenticalFilesTogether() async throws {
        let fixture = TempDirectoryFixture()
        fixture.makeFile("a.txt", byteCount: 300)
        fixture.makeFile("b.txt", byteCount: 300)
        fixture.makeFile("c.txt", byteCount: 300)

        let tree = await DirectoryScanner().scan(rootPath: fixture.path)
        let groups = await DuplicateFinder.findDuplicates(in: tree)
        #expect(groups.count == 1)
        #expect(groups[0].nodeIDs.count == 3)
    }

    @Test func zeroByteFilesAreNeverReportedAsDuplicates() async throws {
        let fixture = TempDirectoryFixture()
        fixture.makeFile("a.txt", byteCount: 0)
        fixture.makeFile("b.txt", byteCount: 0)

        let tree = await DirectoryScanner().scan(rootPath: fixture.path)
        let groups = await DuplicateFinder.findDuplicates(in: tree)
        #expect(groups.isEmpty)
    }

    @Test func noDuplicatesWhenEveryFileIsUnique() async throws {
        let fixture = TempDirectoryFixture()
        fixture.makeFile("a.txt", byteCount: 10)
        fixture.makeFile("b.txt", byteCount: 20)
        fixture.makeFile("c.txt", byteCount: 30)

        let tree = await DirectoryScanner().scan(rootPath: fixture.path)
        let groups = await DuplicateFinder.findDuplicates(in: tree)
        #expect(groups.isEmpty)
    }
}
