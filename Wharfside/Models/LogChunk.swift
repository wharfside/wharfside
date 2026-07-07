// Models/LogChunk.swift

import Foundation
import WharfsideAnalysis

struct LogChunk: Sendable, Hashable {
    let source: LogSource
    let data: Data
}
