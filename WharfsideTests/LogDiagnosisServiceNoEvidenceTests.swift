// WharfsideTests/LogDiagnosisServiceNoEvidenceTests.swift
// B8 — precheck.no-evidence app-tier contract (deterministic per-PR tier).
// Boot-log-only, no error content, no stop signature, non-zero exit short-circuits
// the model; §4c boundaries (exit-0, stop-escalation, error-content) must NOT fire it.
// The rulebook is loaded from bundled JSON without signature verification so this tier
// stays signing-independent and deterministic (no live-model dependency).

import Foundation
import RulebookCore
import Testing
import WharfsideAnalysis
@testable import Wharfside

@MainActor
@Suite struct LogDiagnosisServiceNoEvidenceTests {
  @Test func noEvidenceExitShortCircuitsModelWithUnknownLowConfidence() async throws {
    let session = StubDiagnosisSession(mode: .emit(sampleDiagnosis))
    let service = try makeNoEvidenceService(
      session: session,
      exitStatus: .unavailable(reason: .runtimeGone)
    )
    let entries = try LabeledFixtureParser.loadBootLog(named: "exit_no_output_misdiagnosed_or_timeout.log")
    let container = sampleDetail(id: "diag-crush", image: "docker.io/library/alpine:latest")

    let result = try await service.diagnose(container: container, entries: entries)

    #expect(session.streamCallCount == 0)
    #expect(result.source == .deterministicPrecheck(ruleID: "precheck.no-evidence"))
    #expect(result.diagnosis.category == .unknown)
    #expect(result.diagnosis.confidence == .low)
    #expect(result.diagnosis.summary.contains("(status 1)"))
    #expect(result.diagnosis.summary.contains("without writing any application output"))
    #expect(result.diagnosis.suggestedActions.first?.contains("container logs diag-crush") == true)
    #expect(result.ruleMetadata.precheckRuleID == "precheck.no-evidence")
    #expect(result.ruleMetadata.matchedRuleIDs.contains("precheck.no-evidence"))
    #expect(result.ruleMetadata.matchedRuleIDs.contains("noise.vminitd-memory-threshold"))
    #expect(!result.ruleMetadata.matchedRuleIDs.contains("precheck.stop-escalation"))

    let report = renderReport(result: result, container: container)
    #expect(report.contains("Diagnosed by: deterministic precheck (precheck.no-evidence; model not invoked)"))
    #expect(report.contains("Rules fired: precheck.no-evidence, noise.vminitd-memory-threshold"))
  }

  // §4c boundary: a clean exit-0 with no output is NOT a failure — the model path proceeds.
  @Test func exitZeroNoOutputDoesNotFireNoEvidence() async throws {
    let session = StubDiagnosisSession(mode: .emit(neutralUnknownDiagnosis))
    let service = try makeNoEvidenceService(
      session: session,
      exitStatus: .unavailable(reason: .runtimeGone)
    )

    let result = try await service.diagnose(
      container: sampleDetail(id: "quiet", image: "docker.io/library/alpine:latest"),
      entries: exitZeroNoOutputBootEntries()
    )

    #expect(session.streamCallCount >= 1)
    #expect(result.source == .onDeviceModel)
    #expect(!result.ruleMetadata.matchedRuleIDs.contains("precheck.no-evidence"))
  }

  // §4c boundary: boot-only WITH error content has evidence to analyze → model path proceeds.
  @Test func bootOnlyWithErrorContentDoesNotFireNoEvidence() async throws {
    let session = StubDiagnosisSession(mode: .emit(neutralUnknownDiagnosis))
    let service = try makeNoEvidenceService(
      session: session,
      exitStatus: .unavailable(reason: .runtimeGone)
    )
    let entries = try LabeledFixtureParser.loadBootLog(named: "boot_only_crash.log")

    let result = try await service.diagnose(
      container: sampleDetail(id: "crash", image: "docker.io/library/alpine:latest"),
      entries: entries
    )

    #expect(session.streamCallCount >= 1)
    #expect(result.source == .onDeviceModel)
    #expect(!result.ruleMetadata.matchedRuleIDs.contains("precheck.no-evidence"))
  }

  // §4c boundary: report2/hello stop-escalation still wins; no-evidence must never appear.
  @Test func report2StillStopEscalatesAndNoEvidenceNeverFires() async throws {
    let session = StubDiagnosisSession(mode: .emit(neutralUnknownDiagnosis))
    let service = try makeNoEvidenceService(
      session: session,
      exitStatus: .unavailable(reason: .runtimeGone)
    )
    let entries = try LabeledFixtureParser.loadBootLog(named: "stop_timeout_misdiagnosed_as_oom.log")
    let container = sampleDetail(id: "hello", image: "docker.io/library/alpine:latest")

    let result = try await service.diagnose(container: container, entries: entries)

    #expect(session.streamCallCount == 0)
    #expect(result.source == .deterministicPrecheck(ruleID: "precheck.stop-escalation"))
    #expect(!result.ruleMetadata.matchedRuleIDs.contains("precheck.no-evidence"))
    #expect(!renderReport(result: result, container: container).contains("precheck.no-evidence"))
  }
}

// MARK: - Helpers

@MainActor
private func makeNoEvidenceService(
  session: StubDiagnosisSession,
  exitStatus: WharfsideAnalysis.ExitStatus
) throws -> LogDiagnosisService {
  LogDiagnosisService(
    availability: StubProvider(sequence: [.full]),
    lifecycleObserver: ContainerLifecycleObserver(),
    containerService: ExitStatusStubContainerService(exitStatus: exitStatus),
    sessionFactory: session,
    rulebookPipeline: try bundledNoEvidencePipeline()
  )
}

/// Decodes the shipped Rulebook.json (which now contains precheck.no-evidence) directly,
/// bypassing signature verification so this tier does not depend on `make sign-rulebook`.
private func bundledNoEvidencePipeline() throws -> RulebookPipeline {
  let url = try #require(Bundle.main.url(forResource: "Rulebook", withExtension: "json"))
  let rulebook = try JSONDecoder().decode(Rulebook.self, from: Data(contentsOf: url))
  #expect(rulebook.rules.contains { rule in
    if case .precheck(let precheck) = rule { return precheck.id == "precheck.no-evidence" }
    return false
  })
  return RulebookPipeline(rulebook: rulebook, source: .bundled)
}

@MainActor
private func renderReport(result: DiagnosisResult, container: ContainerDetail) -> String {
  DiagnosisReportFormatter.render(
    result: result,
    container: container,
    environment: DiagnosisReportEnvironment(
      wharfsideVersion: "0.1.1",
      runtimeVersionLabel: "1.0.0 (commit ee848e3)",
      macOSVersion: "26.5.2",
      generatedAt: Date(timeIntervalSince1970: 1_783_576_497)
    )
  )
}

@MainActor
private let neutralUnknownDiagnosis = ContainerDiagnosis(
  summary: "Inconclusive from the available evidence.",
  category: .unknown,
  suggestedActions: ["Inspect the container configuration"],
  confidence: .low
)

private func exitZeroNoOutputBootEntries() -> [LogEntry] {
  [
    LogEntry(
      timestamp: nil,
      level: .info,
      message: "id: quiet, pid: 109 started managed process",
      raw: "2026-07-16T07:49:10.876Z info vminitd: id: quiet, pid: 109 started managed process",
      source: .boot
    ),
    LogEntry(
      timestamp: nil,
      level: .info,
      message: "id: quiet, status: 0 managed process exit",
      raw: "2026-07-16T07:49:10.877Z info vminitd: id: quiet, status: 0 managed process exit",
      source: .boot
    )
  ]
}
