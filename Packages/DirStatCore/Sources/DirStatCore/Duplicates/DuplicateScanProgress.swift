// SPDX-License-Identifier: GPL-2.0-or-later
/// Live progress for `DuplicateFinder.findDuplicates`, sampled by polling
/// `snapshot()` (same pattern as `ScanProgressCounter` for the initial scan)
/// rather than pushed per-file, so reporting progress never adds an actor hop
/// to the hot hashing loop.
public actor DuplicateScanProgress {
    public struct Snapshot: Sendable, Equatable {
        /// 1 = the cheap partial-hash filter pass, 2 = the full-hash confirmation
        /// pass over whatever survived phase 1.
        public let phase: Int
        public let processed: Int
        public let total: Int

        public init(phase: Int, processed: Int, total: Int) {
            self.phase = phase
            self.processed = processed
            self.total = total
        }
    }

    private var phase = 1
    private var processed = 0
    private var total = 0

    public init() {}

    func startPhase(_ phase: Int, total: Int) {
        self.phase = phase
        self.processed = 0
        self.total = total
    }

    func increment() {
        processed += 1
    }

    public func snapshot() -> Snapshot {
        Snapshot(phase: phase, processed: processed, total: total)
    }
}
