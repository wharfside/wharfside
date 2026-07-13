import Foundation
import RulebookCore
import Testing
@testable import WharfsideAnalysis

@Test func matchContextScopesBootLogToFinalCycle() throws {
    let entries = try BootFixtureEntries.loadBootLog(named: "stop_timeout_misdiagnosed_as_oom.log")
    let context = ContainerContext(
        containerName: "hello",
        image: "docker.io/library/alpine:latest",
        exitStatus: .known(137, source: .bootLog),
        restartCount: 0
    )

    let matchContext = MatchContextBuilder.make(entries: entries, context: context)
    #expect(matchContext.exitCode == 137)
    #expect(matchContext.source == "bootLogOnly")
    #expect(matchContext.logLines.contains { $0.contains("sending signal 15 to process") })
    #expect(matchContext.logLines.contains { $0.contains("status: 137 managed process exit") })
    #expect(matchContext.logLines.contains { $0.localizedCaseInsensitiveContains("memory threshold exceeded") })
    #expect(!matchContext.logLines.contains { $0.contains("sending signal 15") && $0.contains("2026-07-06") })
}

@Test func report2DigestDemotesVminitdNoiseAndEmitsPrecheckFact() throws {
    let entries = try BootFixtureEntries.loadBootLog(named: "stop_timeout_misdiagnosed_as_oom.log")
    let context = ContainerContext(
        containerName: "hello",
        image: "docker.io/library/alpine:latest",
        exitStatus: .known(137, source: .bootLog),
        restartCount: 0
    )
    let window = DigestWindow(description: "logs before container exit")
    let result = LogDigestBuilder().buildWithRules(
        entries: entries,
        context: context,
        window: window
    )
    let rendered = PromptRenderer().render(result.digest)

    #expect(result.evaluation.precheckConclusion?.ruleID == "precheck.stop-escalation")
    #expect(result.evaluation.precheckConclusion?.category == "stopped")
    #expect(result.evaluation.matchedRuleIDs.contains("precheck.stop-escalation"))
    #expect(result.evaluation.matchedRuleIDs.contains("noise.vminitd-memory-threshold"))
    #expect(result.digest.facts.contains { $0.contains("orderly stop") })
    #expect(rendered.contains("FACTS:"))
    #expect(!result.digest.lastLines.contains { $0.localizedCaseInsensitiveContains("memory threshold exceeded") })
    #expect(!result.digest.topPatterns.contains {
        $0.template.localizedCaseInsensitiveContains("memory threshold")
    })
    #expect(rendered.contains("sending signal 15 to process"))
    #expect(rendered.contains("EXIT_CODE: 137 (from boot log)"))
    // Final-cycle scoping: no multi-boot [10x] kernel spam from earlier cycles.
    #expect(!result.digest.topPatterns.contains { $0.count >= 10 })
}

@Test func matchContextAndDigestShareFinalCycleWindow() throws {
    let entries = try BootFixtureEntries.loadBootLog(named: "stop_timeout_misdiagnosed_as_oom.log")
    let context = ContainerContext(
        containerName: "hello",
        image: "docker.io/library/alpine:latest",
        exitStatus: .known(137, source: .bootLog),
        restartCount: 0
    )
    let matchContext = MatchContextBuilder.make(entries: entries, context: context)
    #expect(matchContext.logLines.contains { $0.localizedCaseInsensitiveContains("memory threshold exceeded") })
    #expect(matchContext.logLines.contains { $0.contains("started managed process") })
    #expect(matchContext.logLines.contains { $0.contains("sending signal 15") })

    let evaluation = RulebookPipeline.load(rulebookData: nil).evaluate(entries: entries, context: context)
    #expect(evaluation.matchedRuleIDs.contains("noise.vminitd-memory-threshold"))
}

@Test func bootNoiseContaminationDemotesBootOnlyVminitdLines() throws {
    let entries = try LabeledFixtureLoader.loadLog(named: "boot_noise_contamination.log")
    let context = ContainerContext(
        containerName: "crashy",
        image: "crashy:latest",
        exitStatus: .known(1, source: .runtime),
        restartCount: 0
    )
    let result = LogDigestBuilder().buildWithRules(
        entries: entries,
        context: context,
        window: DigestWindow(description: "logs before container exit")
    )
    let digest = result.digest
    let rendered = PromptRenderer().render(digest)

    #expect(digest.counts["ERROR", default: 0] == 1)
    #expect(digest.firstError?.contains("No space left on device") == true)
    #expect(!digest.bootLines.contains { $0.localizedCaseInsensitiveContains("memory threshold exceeded") })
    #expect(!digest.topPatterns.contains { $0.template.localizedCaseInsensitiveContains("vminitd") })
    #expect(rendered.contains("BOOT_LOG"))
}

@Test func hostileStdioForgedSignalsDoNotTriggerPrecheck() throws {
    let entries = try LabeledFixtureLoader.loadLog(named: "exit_status_hostile_stdio.log")
    let context = ContainerContext(
        containerName: "hello",
        image: "docker.io/library/alpine:latest",
        exitStatus: .known(137, source: .bootLog),
        restartCount: 0
    )
    let result = LogDigestBuilder().buildWithRules(
        entries: entries,
        context: context,
        window: DigestWindow(description: "logs before container exit")
    )

    #expect(result.evaluation.precheckConclusion == nil)
    #expect(result.digest.lastLines.contains { $0.contains("sending signal 15") })
    #expect(!result.digest.bootLines.contains { $0.localizedCaseInsensitiveContains("memory threshold exceeded") })
}

@Test func corruptJSONBracketFallsBackToSeedRules() throws {
    var data = try SeedRulebook.bundledJSON
    data[data.startIndex] = data[data.startIndex] == UInt8(ascii: "{") ? UInt8(ascii: "[") : UInt8(ascii: "{")
    let pipeline = RulebookPipeline.load(rulebookData: data)
    #expect(pipeline.source == .fallback)
    #expect(pipeline.rulebook == SeedRulebook.make())
}

@Test func nonJSONBytesFallBackToSeedRules() {
    let pipeline = RulebookPipeline.load(rulebookData: Data("not json".utf8))
    #expect(pipeline.source == .fallback)
    #expect(pipeline.rulebook == SeedRulebook.make())
}

@Test func truncatedJSONFallsBackToSeedRules() throws {
    let data = try SeedRulebook.bundledJSON
    let truncated = Data(data.prefix(data.count / 2))
    let pipeline = RulebookPipeline.load(rulebookData: truncated)
    #expect(pipeline.source == .fallback)
    #expect(pipeline.rulebook == SeedRulebook.make())
}

@Test func crashyDigestDoesNotClaimNoiseFiredWithoutThresholdLine() throws {
    let entries = try LabeledFixtureLoader.loadLog(named: "boot_noise_contamination.log")
    // Strip the threshold-exceeded boot lines so only config-style noise remains —
    // the stdio disk-full case must not list noise.vminitd-memory-threshold as fired.
    let withoutThreshold = entries.filter {
        !$0.raw.localizedCaseInsensitiveContains("memory threshold exceeded")
    }
    let context = ContainerContext(
        containerName: "crashy",
        image: "crashy:latest",
        exitStatus: .known(1, source: .runtime),
        restartCount: 0
    )
    let result = LogDigestBuilder().buildWithRules(
        entries: withoutThreshold,
        context: context,
        window: DigestWindow(description: "logs before container exit")
    )
    #expect(!result.evaluation.matchedRuleIDs.contains("noise.vminitd-memory-threshold"))
    #expect(result.evaluation.noisePatterns.isEmpty)
}

@Test func digestBuildIsDeterministicWithRules() throws {
    let entries = try BootFixtureEntries.loadBootLog(named: "stop_timeout_misdiagnosed_as_oom.log")
    let context = ContainerContext(
        containerName: "hello",
        image: "docker.io/library/alpine:latest",
        exitStatus: .known(137, source: .bootLog),
        restartCount: 0
    )
    let window = DigestWindow(description: "logs before container exit")
    let builder = LogDigestBuilder()
    let renderer = PromptRenderer()

    let first = renderer.render(builder.buildWithRules(entries: entries, context: context, window: window).digest)
    let second = renderer.render(builder.buildWithRules(entries: entries, context: context, window: window).digest)
    #expect(first == second)
    #expect(first.data(using: .utf8) == second.data(using: .utf8))
}
