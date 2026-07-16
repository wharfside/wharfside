// WharfsideTests/LogRingBufferTests.swift

import Foundation
import Testing
import WharfsideAnalysis
@testable import Wharfside

struct LogRingBufferTests {
    @Test func appendPreservesOrder() {
        var buffer = LogRingBuffer()
        buffer.append(chunk: LogChunk(source: .stdio, data: Data("alpha\nbeta\n".utf8)))

        #expect(buffer.count == 2)
        #expect(buffer.lines.map(\.text) == ["alpha", "beta"])
        #expect(buffer.lines.map(\.id) == [1, 2])
    }

    @Test func partialLineAcrossChunks() {
        var buffer = LogRingBuffer()
        buffer.append(chunk: LogChunk(source: .stdio, data: Data("hel".utf8)))
        #expect(buffer.lines.isEmpty)

        buffer.append(chunk: LogChunk(source: .stdio, data: Data("lo\nworld\n".utf8)))
        #expect(buffer.lines.map(\.text) == ["hello", "world"])
    }

    @Test func capacityDropsOldestLines() {
        var buffer = LogRingBuffer(capacity: 3)
        let payload = "one\ntwo\nthree\nfour\n"
        buffer.append(chunk: LogChunk(source: .stdio, data: Data(payload.utf8)))

        #expect(buffer.count == 3)
        #expect(buffer.lines.map(\.text) == ["two", "three", "four"])
        #expect(buffer.lines.first?.id == 2)
        #expect(buffer.lines.last?.id == 4)
    }

    @Test func levelParsingUsesWharfsideAnalysis() {
        var buffer = LogRingBuffer()
        buffer.append(chunk: LogChunk(source: .stdio, data: Data("Mon Jul 6 15:38:42 UTC 2026 ERROR boom\n".utf8)))

        #expect(buffer.lines.first?.level == .error)
        #expect(buffer.lines.first?.entry.level == .error)
    }

    @Test func recentEntriesRespectsWindow() {
        var buffer = LogRingBuffer()
        let oldDate = Date(timeIntervalSince1970: 1_000)
        let recentDate = Date(timeIntervalSince1970: 2_000)
        buffer.append(chunk: LogChunk(source: .stdio, data: Data("old\n".utf8)), receivedAt: oldDate)
        buffer.append(chunk: LogChunk(source: .stdio, data: Data("new\n".utf8)), receivedAt: recentDate)

        let entries = buffer.recentEntries(within: .seconds(100), now: recentDate)
        #expect(entries.count == 1)
        #expect(entries.first?.raw == "new")
        #expect(entries.first?.source == .stdio)
    }

    @Test func recentEntriesCollapsesReReadSnapshots() {
        var buffer = LogRingBuffer()
        // A re-fetched whole-file snapshot appends byte-identical lines; the display buffer
        // keeps them, but the diagnosis window must not inflate frequency evidence.
        let snapshot = LogChunk(source: .stdio, data: Data("ERROR boom\n".utf8))
        buffer.append(chunk: snapshot)
        buffer.append(chunk: snapshot)
        buffer.append(chunk: snapshot)

        #expect(buffer.count == 3)

        let entries = buffer.recentEntries(within: .seconds(3600))
        #expect(entries.count == 1)
        #expect(entries.first?.raw == "ERROR boom")
    }

    @Test func recentEntriesFoldsUntimestampedRepeatsWithinOneFetch() {
        // Accepted, deliberate limitation (called out in the PR body): the dedup identity is
        // (source, embedded timestamp, raw line). N genuinely-distinct untimestamped
        // occurrences arriving in a single snapshot are indistinguishable from one line
        // re-read N times across snapshots — the buffer keeps no per-fetch provenance — so
        // both fold to one. This undercounts duplicate spam ([1x] when reality was [3x]).
        // The bug this replaced OVERcounted ([3x] when reality was [1x]), which fabricates
        // evidence; undercounting is the honest side of the line. This test pins the choice so
        // any future change to distinguish the two cases is made consciously.
        var buffer = LogRingBuffer()
        buffer.append(
            chunk: LogChunk(source: .stdio, data: Data("ERROR boom\nERROR boom\nERROR boom\n".utf8))
        )

        #expect(buffer.count == 3)
        let entries = buffer.recentEntries(within: .seconds(3600))
        #expect(entries.count == 1)
    }

    @Test func recentEntriesKeepsDistinctTimestampedRepeats() {
        var buffer = LogRingBuffer()
        // Genuine repeats carry distinct embedded timestamps, so they survive dedup.
        buffer.append(
            chunk: LogChunk(source: .stdio, data: Data("2026-07-16T10:00:01Z ERROR retry\n".utf8))
        )
        buffer.append(
            chunk: LogChunk(source: .stdio, data: Data("2026-07-16T10:00:02Z ERROR retry\n".utf8))
        )

        let entries = buffer.recentEntries(within: .seconds(3600))
        #expect(entries.count == 2)
    }

    @Test func recentEntriesPreservesSource() {
        var buffer = LogRingBuffer()
        buffer.append(chunk: LogChunk(source: .boot, data: Data("boot line\n".utf8)))

        let entries = buffer.recentEntries(within: .seconds(3600))
        #expect(entries.count == 1)
        #expect(entries.first?.source == .boot)
    }

    @Test func sourceFilterExcludesOtherHandles() {
        var buffer = LogRingBuffer()
        buffer.append(chunk: LogChunk(source: .stdio, data: Data("stdio\n".utf8)))
        buffer.append(chunk: LogChunk(source: .boot, data: Data("boot\n".utf8)))

        let stdioOnly = buffer.filtered(search: "", sources: .stdio)
        #expect(stdioOnly.lines.map(\.text) == ["stdio"])

        let bootOnly = buffer.filtered(search: "", sources: .boot)
        #expect(bootOnly.lines.map(\.text) == ["boot"])
    }
}
