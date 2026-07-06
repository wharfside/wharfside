// WharfsideTests/ContainerDetailViewModelTests.swift

import Foundation
import Testing
@testable import Wharfside

@MainActor
struct ContainerDetailViewModelTests {
    @Test func successfulLoadPopulatesDetail() async {
        let service = MockContainerService()
        service.detailsByID["app"] = .mock(id: "app")
        let viewModel = ContainerDetailViewModel(containerID: "app", service: service)

        await viewModel.refresh()

        #expect(viewModel.detail?.id == "app")
        #expect(viewModel.detail?.ports.count == 1)
        #expect(viewModel.detail?.mounts.count == 1)
        #expect(viewModel.detail?.environment.count == 1)
        #expect(viewModel.detail?.networks.count == 1)
        #expect(!viewModel.isGone)
        #expect(!viewModel.isInitialLoading)
    }

    @Test func notFoundOnLoadShowsGoneState() async {
        let service = MockContainerService()
        service.getError = WharfsideError.notFound("container app not found")
        let viewModel = ContainerDetailViewModel(containerID: "app", service: service)

        await viewModel.refresh()

        #expect(viewModel.detail == nil)
        #expect(viewModel.isGone)
    }

    @Test func notFoundDuringPollShowsGoneState() async {
        let service = MockContainerService()
        service.detailsByID["app"] = .mock(id: "app")
        let viewModel = ContainerDetailViewModel(
            containerID: "app",
            service: service,
            pollInterval: .milliseconds(40)
        )

        await viewModel.refresh()
        #expect(!viewModel.isGone)

        service.getError = WharfsideError.notFound("container app not found")
        viewModel.startPolling()
        try? await Task.sleep(for: .milliseconds(120))
        viewModel.stopPolling()

        #expect(viewModel.isGone)
        #expect(viewModel.detail == nil)
    }

    @Test func pollStartsOnAppearAndStopsAfterDisappear() async {
        let service = MockContainerService()
        service.detailsByID["app"] = .mock(id: "app")
        service.getDelay = .milliseconds(30)
        let viewModel = ContainerDetailViewModel(
            containerID: "app",
            service: service,
            pollInterval: .milliseconds(30)
        )

        viewModel.startPolling()
        try? await Task.sleep(for: .milliseconds(120))
        let countAfterStart = service.getCallCount

        viewModel.stopPolling()
        try? await Task.sleep(for: .milliseconds(120))

        #expect(service.getCallCount == countAfterStart)
    }

    @Test func destructiveActionWaitsForConfirmation() async {
        let service = MockContainerService()
        service.detailsByID["app"] = .mock(id: "app", status: .running)
        let viewModel = ContainerDetailViewModel(containerID: "app", service: service)
        await viewModel.refresh()

        viewModel.actions.requestStop(id: "app")
        #expect(viewModel.actions.pendingConfirmation == .stop("app"))
        #expect(service.stopCallCount == 0)

        await viewModel.actions.confirm(.stop("app"))
        #expect(service.stopCallCount == 1)
    }

    @Test func stopShowsStoppingUntilPollConfirmsStopped() async {
        let service = MockContainerService()
        service.detailsByID["app"] = .mock(id: "app", status: .running)
        let viewModel = ContainerDetailViewModel(containerID: "app", service: service, pollInterval: .seconds(60))
        await viewModel.refresh()

        await viewModel.actions.confirm(.stop("app"))

        #expect(viewModel.actions.pendingDisplayByID["app"] == .stopping)
        #expect(viewModel.displayStatusLabel(for: viewModel.detail!) == "Stopping…")

        service.detailsByID["app"] = .mock(id: "app", status: .stopped)
        await viewModel.refresh()

        #expect(viewModel.actions.pendingDisplayByID["app"] == nil)
        #expect(viewModel.displayStatusLabel(for: viewModel.detail!) == "Stopped")
    }

    @Test func environmentMaskAndCopyUseRealValue() async {
        let service = MockContainerService()
        service.detailsByID["app"] = .mock(
            id: "app",
            environment: [ContainerEnvironmentVariable(key: "API_KEY", value: "real-secret")]
        )
        let viewModel = ContainerDetailViewModel(containerID: "app", service: service)
        await viewModel.refresh()

        let variable = viewModel.detail?.environment.first
        #expect(variable != nil)
        guard let variable else { return }

        #expect(!viewModel.isEnvironmentValueRevealed(key: variable.key))
        #expect(viewModel.maskedEnvironmentValue(for: variable) == "••••••••")
        #expect(viewModel.environmentValue(for: variable) == "real-secret")

        viewModel.toggleEnvironmentReveal(key: variable.key)
        #expect(viewModel.isEnvironmentValueRevealed(key: variable.key))

        viewModel.toggleEnvironmentReveal(key: variable.key)
        #expect(!viewModel.isEnvironmentValueRevealed(key: variable.key))
    }
}
