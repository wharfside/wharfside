// Services/LogEntriesCollector.swift
// Issue 1.7 — cold log fetch when the Logs tab buffer is empty.

import Foundation
import WharfsideAnalysis

enum LogEntriesCollector {
    /// Per-phase wall-clock cap for cold log collection.
    ///
    /// Stdio is attempted first; if it yields zero parsed entries, boot is collected in a
    /// second phase. Worst case total wait is ~4 s (2 s stdio + 2 s boot).
    static let phaseDuration: Duration = .seconds(2)

    /// Collects a snapshot of container logs via `logStream` when the in-memory buffer is empty.
    ///
    /// Defaults to stdio only (matching the log viewer). Falls back to boot when stdio is
    /// empty — the case where the container dies before application output exists.
    ///
    /// `logStream` polls indefinitely for stopped containers (it never finishes on its own).
    /// Each phase caps wall-clock collection and cancels the consumer so diagnosis cannot hang
    /// after the first chunk is drained.
    static func collect(
        from service: any ContainerServicing,
        containerID: String,
        maxDuration: Duration = .seconds(2)
    ) async -> [LogEntry] {
        let stdioEntries = await collectPhase(
            from: service,
            containerID: containerID,
            source: .stdio,
            maxDuration: maxDuration
        )
        if !stdioEntries.isEmpty {
            DiagnosisLog.info("collected \(stdioEntries.count) log entries for \(containerID)")
            return stdioEntries
        }

        DiagnosisLog.info("stdio empty — falling back to boot log for \(containerID)")
        let bootEntries = await collectPhase(
            from: service,
            containerID: containerID,
            source: .boot,
            maxDuration: maxDuration
        )
        DiagnosisLog.info("collected \(bootEntries.count) boot log entries for \(containerID)")
        return bootEntries
    }

    private static func collectPhase(
        from service: any ContainerServicing,
        containerID: String,
        source: LogSource,
        maxDuration: Duration
    ) async -> [LogEntry] {
        final class Collector: @unchecked Sendable {
            var buffer = LogRingBuffer()
        }
        let collector = Collector()

        let consumeTask = Task {
            let stream = service.logStream(id: containerID, source: source)
            do {
                for try await chunk in stream {
                    collector.buffer.append(chunk: chunk)
                }
            } catch {
                DiagnosisLog.info(
                    "log collect stream ended for \(containerID) (\(source.rawValue)): "
                        + error.localizedDescription
                )
            }
        }

        try? await Task.sleep(for: maxDuration)
        consumeTask.cancel()
        _ = await consumeTask.value

        return collector.buffer.recentEntries(within: .seconds(3600))
    }
}
