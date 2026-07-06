// WharfsideTests/TestPolling.swift

import Foundation

enum TestPolling {
    @MainActor
    static func waitUntil(
        timeout: Duration = .seconds(2),
        pollInterval: Duration = .milliseconds(10),
        _ predicate: () -> Bool
    ) async -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now + timeout
        while clock.now < deadline {
            if predicate() { return true }
            try? await Task.sleep(for: pollInterval)
        }
        return predicate()
    }
}
