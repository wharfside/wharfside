// AI/DiagnosisStreamEvent.swift
// Issue 1.7 — streaming diagnosis events for the diagnosis card UI.

import Foundation
import WharfsideAnalysis

enum DiagnosisStreamEvent: Sendable {
    /// Deterministic exit evidence, resolved during context building before the model runs.
    /// Emitted first so Overview backfill never depends on the model tier finalizing.
    case exitStatusResolved(ExitStatus)
    case partial(ContainerDiagnosis.PartiallyGenerated)
    case finalized(DiagnosisResult)
}
