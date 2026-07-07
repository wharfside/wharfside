import Foundation

/// A single parsed log line (or merged multi-line entry such as a JVM stack trace).
public struct LogEntry: Sendable, Equatable {
    public let timestamp: Date?
    public let level: LogLevel
    public let message: String
    public let raw: String
    /// Log handle the line came from. Defaults to `.stdio` so plain-text fixtures stay unchanged.
    public let source: LogSource

    public init(
        timestamp: Date?,
        level: LogLevel,
        message: String,
        raw: String,
        source: LogSource = .stdio
    ) {
        self.timestamp = timestamp
        self.level = level
        self.message = message
        self.raw = raw
        self.source = source
    }
}
