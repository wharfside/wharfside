// WharfsideTests/LogEntriesCollectorTests.swift

import Foundation
import Testing
import WharfsideAnalysis
@testable import Wharfside

@MainActor
struct LogEntriesCollectorTests {
    @Test func collectReturnsAfterTimeoutWhenStreamNeverFinishes() async {
        let service = MockContainerService()
        service.logStreamFactory = { _, source in
            #expect(source == .stdio)
            return AsyncThrowingStream { continuation in
                continuation.yield(LogChunk(source: .stdio, data: Data("ERROR: disk full\n".utf8)))
            }
        }

        let start = ContinuousClock.now
        let entries = await LogEntriesCollector.collect(
            from: service,
            containerID: "crashy",
            maxDuration: .milliseconds(100)
        )
        let elapsed = start.duration(to: .now)

        #expect(!entries.isEmpty)
        #expect(entries.allSatisfy { $0.source == .stdio })
        #expect(elapsed < .seconds(1))
    }

    @Test func collectFallsBackToBootWhenStdioEmpty() async {
        let service = MockContainerService()
        service.logStreamFactory = { _, source in
            AsyncThrowingStream { continuation in
                if source == .stdio {
                    continuation.finish()
                } else if source == .boot {
                    continuation.yield(
                        LogChunk(source: .boot, data: Data("ERROR: rootfs mount failed\n".utf8))
                    )
                }
            }
        }

        let entries = await LogEntriesCollector.collect(
            from: service,
            containerID: "init-fail",
            maxDuration: .milliseconds(100)
        )

        #expect(entries.count == 1)
        #expect(entries.first?.source == .boot)
        #expect(entries.first?.raw.contains("rootfs mount failed") == true)
    }

    @Test func collectPrefersStdioOverBoot() async {
        let service = MockContainerService()
        service.logStreamFactory = { _, source in
            AsyncThrowingStream { continuation in
                if source == .stdio {
                    continuation.yield(
                        LogChunk(source: .stdio, data: Data("ERROR: No space left on device\n".utf8))
                    )
                }
                continuation.finish()
            }
        }

        let entries = await LogEntriesCollector.collect(
            from: service,
            containerID: "crashy",
            maxDuration: .milliseconds(100)
        )

        #expect(entries.count == 1)
        #expect(entries.first?.source == .stdio)
    }
}
