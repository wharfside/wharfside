// WharfsideTests/CanonicalEvidenceWindowTests.swift
// B8.2 — diagnosis evidence must be a function of the container, not of Logs UI state.
// Commit 1: red fixtures via withKnownIssue. Commits 2–3 remove the wrappers.

import Foundation
import Testing
import WharfsideAnalysis
@testable import Wharfside

@MainActor
@Suite struct CanonicalEvidenceWindowTests {

    /// Simulates the post–Bug-A Logs tab: buffer holds stdio only. Cold-fetch must still
    /// attach boot so EXIT_CODE / BOOT_LOG appendix / noise.vminitd-memory-threshold appear.
    /// Today `LogEntriesCollector` returns early on non-empty stdio, and the card skips
    /// cold-fetch entirely when the buffer is non-empty — so boot evidence is lost.
    @Test func stdioPrimaryBufferAssemblesBootEvidence() async throws {
        let fixture = try LabeledFixtureParser.loadLabeled(
            named: "stdio_primary_loses_boot_evidence.log"
        )
        let stdioOnly = fixture.filter { $0.source == .stdio }
        let bootOnly = fixture.filter { $0.source == .boot }
        #expect(!stdioOnly.isEmpty)
        #expect(!bootOnly.isEmpty)

        let containerService = MockContainerService()
        containerService.exitStatusByID["diag-loud"] = .unavailable(reason: .runtimeGone)
        containerService.logStreamFactory = { _, source in
            AsyncThrowingStream { continuation in
                let lines = (source == .boot ? bootOnly : stdioOnly).map(\.raw)
                for line in lines {
                    let chunkSource: LogSource = source == .boot ? .boot : .stdio
                    continuation.yield(
                        LogChunk(source: chunkSource, data: Data((line + "\n").utf8))
                    )
                }
                continuation.finish()
            }
        }

        let session = StubDiagnosisSession(mode: .emit(canonicalSampleDiagnosis))
        let diagnosisService = LogDiagnosisService(
            availability: StubProvider(sequence: [.full]),
            lifecycleObserver: ContainerLifecycleObserver(),
            containerService: containerService,
            sessionFactory: session
        )
        let viewModel = DiagnosisCardViewModel(
            containerID: "diag-loud",
            diagnosisService: diagnosisService,
            containerService: containerService,
            logEntriesProvider: { stdioOnly }
        )
        viewModel.updateContainer(canonicalStoppedContainer(id: "diag-loud"))

        await withKnownIssue(
            "B8.2: boot evidence must be assembled at diagnosis time, not gated on empty stdio"
        ) {
            viewModel.explain()
            #expect(await TestPolling.waitUntil {
                if case .result = viewModel.phase { return true }
                return false
            })

            guard case .result(let state) = viewModel.phase else {
                Issue.record("Expected result phase")
                return
            }
            let digest = state.result.renderedDigest
            #expect(digest.contains("EXIT_CODE: 1 (from boot log)"))
            #expect(digest.contains("BOOT_LOG (runtime init, usually not the app's crash cause):"))
            #expect(state.result.ruleMetadata.matchedRuleIDs.contains("noise.vminitd-memory-threshold"))
            #expect(state.result.exitStatus == .known(1, source: .bootLog))
        }
    }

    /// Collector must return stdio + boot even when stdio is non-empty (unconditional boot phase).
    @Test func collectIncludesBootEvenWhenStdioPresent() async {
        let fixture: [LogEntry]
        do {
            fixture = try LabeledFixtureParser.loadLabeled(
                named: "stdio_primary_loses_boot_evidence.log"
            )
        } catch {
            Issue.record("Failed to load fixture: \(error)")
            return
        }
        let stdioOnly = fixture.filter { $0.source == .stdio }
        let bootOnly = fixture.filter { $0.source == .boot }

        let service = MockContainerService()
        service.logStreamFactory = { _, source in
            AsyncThrowingStream { continuation in
                let lines = (source == .boot ? bootOnly : stdioOnly).map(\.raw)
                for line in lines {
                    let chunkSource: LogSource = source == .boot ? .boot : .stdio
                    continuation.yield(
                        LogChunk(source: chunkSource, data: Data((line + "\n").utf8))
                    )
                }
                continuation.finish()
            }
        }

        await withKnownIssue(
            "B8.2: LogEntriesCollector must not skip boot when stdio yields entries"
        ) {
            let entries = await LogEntriesCollector.collect(
                from: service,
                containerID: "diag-loud",
                maxDuration: .milliseconds(100)
            )
            #expect(entries.contains { $0.source == .stdio })
            #expect(entries.contains { $0.source == .boot })
            #expect(entries.contains { $0.raw.contains("status: 1 managed process exit") })
        }
    }
}

@MainActor
private let canonicalSampleDiagnosis = ContainerDiagnosis(
    summary: "Application printed an error before exit.",
    category: .applicationBug,
    suggestedActions: ["Inspect the application command"],
    confidence: .medium
)

@MainActor
private func canonicalStoppedContainer(id: String) -> ContainerDetail {
    ContainerDetail(
        id: id,
        image: "docker.io/library/alpine:latest",
        status: .stopped,
        command: ["sh", "-c", "echo ERROR boom; exit 1"],
        createdAt: .now,
        startedAt: nil,
        exitStatus: .unavailable(reason: .runtimeGone),
        restartCount: 0,
        ports: [],
        mounts: [],
        environment: [],
        networks: []
    )
}
