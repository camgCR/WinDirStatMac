// SPDX-License-Identifier: GPL-2.0-or-later
public struct ScanProgress: Sendable, Equatable {
    public var filesScanned: Int
    public var bytesScanned: Int64
    public var isComplete: Bool

    public init(filesScanned: Int = 0, bytesScanned: Int64 = 0, isComplete: Bool = false) {
        self.filesScanned = filesScanned
        self.bytesScanned = bytesScanned
        self.isComplete = isComplete
    }
}

/// Accumulates scan progress from many concurrent workers. Workers record once per
/// directory (batching their own file-level counting locally first) rather than
/// once per file, so a 500k-file scan produces on the order of thousands of actor
/// hops here, not hundreds of thousands.
public actor ScanProgressCounter {
    private var filesScanned = 0
    private var bytesScanned: Int64 = 0
    private var isComplete = false

    public init() {}

    func record(files: Int, bytes: Int64) {
        filesScanned += files
        bytesScanned += bytes
    }

    func markComplete() {
        isComplete = true
    }

    public func snapshot() -> ScanProgress {
        ScanProgress(filesScanned: filesScanned, bytesScanned: bytesScanned, isComplete: isComplete)
    }
}
