import Foundation
import WharfsideAnalysis

/// Parses fixture files with `@stdio` / `@boot` section markers (mirrors package test loader).
enum LabeledFixtureParser {
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

  static func loadBootLog(named filename: String) throws -> [LogEntry] {
    let url = fixtureURL(named: filename)
    let text = try String(contentsOf: url, encoding: .utf8)
    return LogParser().parse(text: text).map {
      LogEntry(
        timestamp: $0.timestamp,
        level: $0.level,
        message: $0.message,
        raw: $0.raw,
        source: .boot
      )
    }
  }

  /// Loads a fixture that may contain `@stdio` / `@boot` section markers.
  static func loadLabeled(named filename: String) throws -> [LogEntry] {
    let text = try String(contentsOf: fixtureURL(named: filename), encoding: .utf8)
    return parse(text: text)
  }

  private static func fixtureURL(named filename: String) -> URL {
    URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appendingPathComponent("Packages/WharfsideAnalysis/Tests/Fixtures/\(filename)")
  }
}
