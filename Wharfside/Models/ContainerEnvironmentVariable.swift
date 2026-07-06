// Models/ContainerEnvironmentVariable.swift

import Foundation

struct ContainerEnvironmentVariable: Sendable, Hashable, Identifiable {
    let key: String
    let value: String

    var id: String { key }
}
