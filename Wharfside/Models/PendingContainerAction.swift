// Models/PendingContainerAction.swift

import Foundation

enum PendingContainerAction: Equatable, Sendable, Identifiable {
    case stop(String)
    case kill(String)
    case delete(String)

    var id: String {
        switch self {
        case .stop(let containerID): "stop-\(containerID)"
        case .kill(let containerID): "kill-\(containerID)"
        case .delete(let containerID): "delete-\(containerID)"
        }
    }

    var containerID: String {
        switch self {
        case .stop(let id), .kill(let id), .delete(let id):
            id
        }
    }
}

enum LifecyclePendingDisplay: Equatable, Sendable {
    case starting
    case stopping
    case deleting

    var label: String {
        switch self {
        case .starting: "Starting…"
        case .stopping: "Stopping…"
        case .deleting: "Deleting…"
        }
    }
}

enum ContainerActionSupport {
    static func confirmationTitle(for action: PendingContainerAction) -> String {
        switch action {
        case .stop: return "Stop container?"
        case .kill: return "Kill container?"
        case .delete: return "Delete container?"
        }
    }

    static func confirmationMessage(
        for action: PendingContainerAction,
        containerName: String,
        status: ContainerRuntimeStatus?
    ) -> String {
        switch action {
        case .stop:
            return "Container \(containerName) will receive a graceful stop signal."
        case .kill:
            return "Container \(containerName) will be killed immediately."
        case .delete:
            if status == .running || status == .stopping {
                return "Container \(containerName) is still running. Force delete will stop and remove it."
            }
            return "Container \(containerName) will be permanently removed."
        }
    }

    static func destructiveConfirmationLabel(
        for action: PendingContainerAction,
        status: ContainerRuntimeStatus?
    ) -> String {
        switch action {
        case .stop: return "Stop"
        case .kill: return "Kill"
        case .delete:
            if status == .running || status == .stopping {
                return "Force Delete"
            }
            return "Delete"
        }
    }

    static func deleteRequiresForce(status: ContainerRuntimeStatus?) -> Bool {
        status == .running || status == .stopping
    }
}
