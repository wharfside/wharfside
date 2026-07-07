// WharfsideTests/LogStreamTests.swift

import Testing
import WharfsideAnalysis
@testable import Wharfside

@MainActor
struct LogStreamTests {
    @Test func cancellationFinishesStream() async throws {
        let service = MockContainerService()
        let stream = service.logStream(id: "mock", source: nil as LogSource?)

        var received = 0
        let consumeTask = Task {
            for try await _ in stream {
                received += 1
            }
        }

        try await Task.sleep(for: .milliseconds(50))
        consumeTask.cancel()

        _ = try? await consumeTask.value
        #expect(received >= 1)
    }
}
