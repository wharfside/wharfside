import Foundation

/// Origin of a log line within the apple/container runtime.
public enum LogSource: String, Sendable, Hashable, CaseIterable {
    case stdio
    case boot
}
