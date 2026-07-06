// Models/ContainerNetworkAttachment.swift

import Foundation

struct ContainerNetworkAttachment: Sendable, Hashable, Identifiable {
    let network: String
    let hostname: String
    let ipv4Address: String
    let ipv4Gateway: String
    let ipv6Address: String?

    var id: String { network }
}
