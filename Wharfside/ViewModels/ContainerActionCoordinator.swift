// ViewModels/ContainerActionCoordinator.swift

import Foundation
import Observation

@MainActor
@Observable
final class ContainerActionCoordinator {
    private(set) var actionInProgressIDs: Set<String> = []
    private(set) var actionBannerMessage: String?
    private(set) var pendingDisplayByID: [String: LifecyclePendingDisplay] = [:]

    var pendingConfirmation: PendingContainerAction?
    var onActionSucceeded: (@Sendable (String) async -> Void)?

    private let service: any ContainerServicing
    private var bannerClearTask: Task<Void, Never>?
    var statusProvider: (String) -> ContainerRuntimeStatus?

    init(
        service: any ContainerServicing,
        statusProvider: @escaping (String) -> ContainerRuntimeStatus? = { _ in nil }
    ) {
        self.service = service
        self.statusProvider = statusProvider
    }

    func requestStart(id: String) {
        Task { await performStart(id: id) }
    }

    func requestStop(id: String) {
        pendingConfirmation = .stop(id)
    }

    func requestKill(id: String) {
        pendingConfirmation = .kill(id)
    }

    func requestDelete(id: String) {
        pendingConfirmation = .delete(id)
    }

    func cancelPendingAction() {
        pendingConfirmation = nil
    }

    func confirm(_ action: PendingContainerAction) async {
        pendingConfirmation = nil

        switch action {
        case .stop(let id):
            await performStop(id: id)
        case .kill(let id):
            await performKill(id: id)
        case .delete(let id):
            let force = ContainerActionSupport.deleteRequiresForce(status: statusProvider(id))
            await performDelete(id: id, force: force)
        }
    }

    func confirmationTitle(for action: PendingContainerAction) -> String {
        ContainerActionSupport.confirmationTitle(for: action)
    }

    func confirmationMessage(for action: PendingContainerAction) -> String {
        ContainerActionSupport.confirmationMessage(
            for: action,
            containerName: action.containerID,
            status: statusProvider(action.containerID)
        )
    }

    func destructiveConfirmationLabel(for action: PendingContainerAction) -> String {
        ContainerActionSupport.destructiveConfirmationLabel(
            for: action,
            status: statusProvider(action.containerID)
        )
    }

    func displayStatusLabel(for id: String, actual: ContainerRuntimeStatus) -> String {
        if let pending = pendingDisplayByID[id] {
            return pending.label
        }
        return ContainerSummaryFormatting.statusLabel(actual)
    }

    func listStatusSummary(for container: ContainerSummary, now: Date = .now) -> String {
        if let pending = pendingDisplayByID[container.id] {
            return pending.label
        }
        return ContainerSummaryFormatting.uptimeOrExitSummary(
            status: container.status,
            startedAt: container.startedAt,
            now: now
        )
    }

    func reconcilePendingDisplay(containerID: String, actualStatus: ContainerRuntimeStatus) {
        guard let pending = pendingDisplayByID[containerID] else { return }

        let resolved = switch pending {
        case .starting:
            actualStatus == .running
        case .stopping:
            actualStatus == .stopping || actualStatus == .stopped || actualStatus == .unknown
        case .deleting:
            false
        }

        if resolved {
            clearPending(for: containerID)
        }
    }

    func reconcileDeletedContainers(remainingIDs: Set<String>) {
        for id in pendingDisplayByID.keys where pendingDisplayByID[id] == .deleting {
            if !remainingIDs.contains(id) {
                clearPending(for: id)
            }
        }
    }

    func clearPending(for id: String) {
        pendingDisplayByID.removeValue(forKey: id)
        actionInProgressIDs.remove(id)
    }

    func clearActionSpinner(for id: String) {
        actionInProgressIDs.remove(id)
    }

    func clearAllActionSpinners() {
        actionInProgressIDs.removeAll()
        pendingDisplayByID.removeAll()
    }

    func presentTransientBanner(_ message: String) {
        showActionBanner(message)
    }

    private func performStart(id: String) async {
        actionInProgressIDs.insert(id)
        do {
            try await service.start(id: id)
            pendingDisplayByID[id] = .starting
            showActionBanner(nil)
            await onActionSucceeded?(id)
        } catch {
            clearPending(for: id)
            showActionBanner(ErrorMapper.map(error).localizedDescription)
        }
    }

    private func performStop(id: String) async {
        actionInProgressIDs.insert(id)
        do {
            try await service.stop(id: id, timeout: 10)
            pendingDisplayByID[id] = .stopping
            showActionBanner(nil)
            await onActionSucceeded?(id)
        } catch {
            clearPending(for: id)
            showActionBanner(ErrorMapper.map(error).localizedDescription)
        }
    }

    private func performKill(id: String) async {
        actionInProgressIDs.insert(id)
        do {
            try await service.kill(id: id, signal: "KILL")
            pendingDisplayByID[id] = .stopping
            showActionBanner(nil)
            await onActionSucceeded?(id)
        } catch {
            clearPending(for: id)
            showActionBanner(ErrorMapper.map(error).localizedDescription)
        }
    }

    private func performDelete(id: String, force: Bool) async {
        actionInProgressIDs.insert(id)
        do {
            try await service.delete(id: id, force: force)
            pendingDisplayByID[id] = .deleting
            showActionBanner(nil)
            await onActionSucceeded?(id)
        } catch {
            clearPending(for: id)
            showActionBanner(ErrorMapper.map(error).localizedDescription)
        }
    }

    private func showActionBanner(_ message: String?) {
        bannerClearTask?.cancel()
        actionBannerMessage = message
        guard message != nil else { return }
        bannerClearTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            self?.actionBannerMessage = nil
        }
    }
}
