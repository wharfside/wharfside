// Models/ContainerMount.swift

import Foundation

struct ContainerMount: Sendable, Hashable, Identifiable {
    let source: String
    let destination: String
    let type: String
    let readOnly: Bool

    var id: String { destination }
}
