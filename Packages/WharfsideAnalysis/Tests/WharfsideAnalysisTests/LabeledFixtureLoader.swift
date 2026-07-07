import Foundation
@testable import WharfsideAnalysis

/// Parses fixture files with `@stdio` / `@boot` section markers for source-labeled entries.
enum LabeledFixtureLoader {
    static func parse(text: String, parser: LogParser = LogParser()) -> [LogEntry] {
        var currentSource: LogSource = .stdio
        var entries: [LogEntry] = []

        for line in text.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed == "@boot" {
                currentSource = .boot
                continue
            }
            if trimmed == "@stdio" {
                currentSource = .stdio
                continue
            }
            if trimmed.isEmpty {
                continue
            }

            let base = parser.parse(lines: [line]).first
                ?? LogEntry(timestamp: nil, level: .unknown, message: line, raw: line)
            entries.append(
                LogEntry(
                    timestamp: base.timestamp,
                    level: base.level,
                    message: base.message,
                    raw: base.raw,
                    source: currentSource
                )
            )
        }

        return entries
    }

    static func loadLog(named filename: String) throws -> [LogEntry] {
        let text = try FixtureLoader.loadLog(named: filename)
        return parse(text: text)
    }
}
