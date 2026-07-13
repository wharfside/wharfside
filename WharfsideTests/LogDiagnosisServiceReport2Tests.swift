// WharfsideTests/LogDiagnosisServiceReport2Tests.swift
// B3 — report2.md precheck short-circuit (deterministic orderly-stop diagnosis).

import Foundation
import Testing
import WharfsideAnalysis
@testable import Wharfside

@MainActor
@Suite struct LogDiagnosisServiceReport2Tests {
  @Test func report2PrecheckShortCircuitsModelWithOrderlyStop() async throws {
    let session = StubDiagnosisSession(mode: .emit(
      ContainerDiagnosis(
        summary: "The container exited due to a memory threshold exceeded by vminitd.",
        category: .outOfMemory,
        suggestedActions: ["Increase memory limit"],
        confidence: .medium
      )
    ))
    let service = LogDiagnosisService(
      availability: StubProvider(sequence: [.full]),
      lifecycleObserver: ContainerLifecycleObserver(),
      containerService: ExitStatusStubContainerService(exitStatus: .unavailable(reason: .runtimeGone)),
      sessionFactory: session
    )

    let entries = try LabeledFixtureParser.loadBootLog(named: "stop_timeout_misdiagnosed_as_oom.log")
    let result = try await service.diagnose(
      container: sampleDetail(
        id: "hello",
        image: "docker.io/library/alpine:latest",
        exitStatus: .known(137, source: .bootLog)
      ),
      entries: entries
    )

    #expect(session.streamCallCount == 0)
    #expect(result.diagnosis.category == .stopped)
    #expect(result.diagnosis.summary.contains("SIGTERM/SIGKILL"))
    #expect(result.source == .deterministicPrecheck(ruleID: "precheck.stop-escalation"))
    #expect(result.ruleMetadata.matchedRuleIDs.contains("precheck.stop-escalation"))
    #expect(result.ruleMetadata.matchedRuleIDs.contains("noise.vminitd-memory-threshold"))
    #expect(!result.ruleMetadata.matchedRuleIDs.contains("validator.oom-needs-kernel-evidence"))
    #expect(!result.ruleMetadata.matchedRuleIDs.contains("prompt.exit-137-stop-hint"))
    #expect(result.ruleMetadata.precheckRuleID == "precheck.stop-escalation")
    #expect(result.renderedDigest.contains("FACTS:"))
    #expect(result.renderedDigest.contains("orderly stop"))
    #expect(!result.renderedDigest.localizedCaseInsensitiveContains("memory threshold exceeded"))
    #expect(!result.wasDegraded)

    let report = DiagnosisReportFormatter.render(
      result: result,
      container: sampleDetail(
        id: "hello",
        image: "docker.io/library/alpine:latest",
        exitStatus: .known(137, source: .bootLog)
      ),
      environment: DiagnosisReportEnvironment(
        wharfsideVersion: "0.1.1",
        runtimeVersionLabel: "1.0.0 (commit ee848e3)",
        macOSVersion: "26.5.2",
        generatedAt: Date(timeIntervalSince1970: 1_700_000_000)
      )
    )
    #expect(report.contains("### Diagnosis"))
    #expect(report.contains("Diagnosed by: deterministic precheck (precheck.stop-escalation; model not invoked)"))
    #expect(!report.contains("what the model said"))
    #expect(report.contains("Rules fired: precheck.stop-escalation, noise.vminitd-memory-threshold"))
    #expect(!report.contains("validator.oom-needs-kernel-evidence"))
  }
}
