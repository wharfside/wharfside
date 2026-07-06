// Models/ContainerPortBinding.swift

import Foundation

struct ContainerPortBinding: Sendable, Hashable, Identifiable {
    let hostAddress: String
    let hostPort: UInt16
    let containerPort: UInt16
    let proto: String

    var id: String { "\(hostAddress):\(hostPort)->\(containerPort)/\(proto)" }

    var displayBinding: String {
        if hostPort == containerPort {
            return "\(hostAddress):\(hostPort)/\(proto)"
        }
        return "\(hostAddress):\(hostPort)->\(containerPort)/\(proto)"
    }
}
