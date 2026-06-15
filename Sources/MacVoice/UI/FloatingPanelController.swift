import AppKit
import Combine
import SwiftUI

@MainActor
final class FloatingPanelController {
    private let panel: NSPanel
    private let controller: VoiceSessionController
    private let settings: AppSettings
    private var hostingController: NSHostingController<WaveformOverlayView>?
    private var cancellables = Set<AnyCancellable>()
    private var hideTask: Task<Void, Never>?

    init(controller: VoiceSessionController, settings: AppSettings) {
        self.controller = controller
        self.settings = settings
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 410, height: 78),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.hidesOnDeactivate = false
        refreshContent()

        controller.$phase
            .removeDuplicates()
            .sink { [weak self] phase in self?.update(for: phase) }
            .store(in: &cancellables)

        settings.$preferredLanguage
            .dropFirst()
            .sink { [weak self] _ in self?.refreshContent() }
            .store(in: &cancellables)
    }

    private func refreshContent() {
        let view = WaveformOverlayView(controller: controller)
        if let hostingController {
            hostingController.rootView = view
        } else {
            let hosting = NSHostingController(rootView: view)
            hostingController = hosting
            panel.contentViewController = hosting
        }
    }

    private func update(for phase: VoiceSessionPhase) {
        hideTask?.cancel()
        switch phase {
        case .idle:
            panel.orderOut(nil)
        case .success:
            show()
            hideTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(2.2))
                guard !Task.isCancelled else { return }
                self?.controller.resetPresentation()
            }
        default:
            show()
        }
    }

    private func show() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let visible = screen.visibleFrame
        let origin = NSPoint(
            x: visible.midX - panel.frame.width / 2,
            y: visible.minY + 42
        )
        panel.setFrameOrigin(origin)
        panel.orderFrontRegardless()
    }
}
