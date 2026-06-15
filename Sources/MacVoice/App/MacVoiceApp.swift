import AppKit
import SwiftData
import SwiftUI

@main
struct MacVoiceApp: App {
    private let modelContainer: ModelContainer
    @StateObject private var appModel: AppModel
    @ObservedObject private var settings: AppSettings

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--ui-testing-reset"), let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
        if arguments.contains("--ui-testing-onboarded") {
            UserDefaults.standard.set(true, forKey: "onboardingCompleted")
        }
        if arguments.contains("--ui-testing-has-api-key") {
            UserDefaults.standard.set(true, forKey: "uiTestingHasAPIKey")
        }
        do {
            let container = try ModelContainer(for: TranscriptionRecord.self)
            modelContainer = container
            let model = AppModel(modelContext: container.mainContext)
            _appModel = StateObject(wrappedValue: model)
            _settings = ObservedObject(wrappedValue: model.settings)
        } catch {
            fatalError("Unable to create MacVoice data store: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup(id: "main") {
            AppRootView()
                .id(settings.preferredLanguage)
                .environmentObject(appModel)
                .environmentObject(settings)
                .modelContainer(modelContainer)
                .task { appModel.start() }
                .frame(minWidth: 760, minHeight: 560)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 920, height: 680)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandMenu("MacVoice") {
                Button(L10n.text("action.toggle_recording")) {
                    appModel.voice.toggleRecording()
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
            }
        }

        MenuBarExtra {
            MenuBarContent()
                .id(settings.preferredLanguage)
                .environmentObject(appModel)
                .environmentObject(settings)
        } label: {
            MenuBarPhaseIcon(controller: appModel.voice)
        }

        Settings {
            SettingsView()
                .id(settings.preferredLanguage)
                .environmentObject(appModel)
                .environmentObject(settings)
                .modelContainer(modelContainer)
                .frame(width: 680, height: 560)
        }
    }

}

private struct AppRootView: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        Group {
            if settings.onboardingCompleted {
                MainView()
                    .transition(.opacity)
            } else {
                OnboardingView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: settings.onboardingCompleted)
    }
}

private struct MenuBarPhaseIcon: View {
    let controller: VoiceSessionController
    @State private var phase: VoiceSessionPhase = .idle

    var body: some View {
        Image(systemName: icon)
            .onAppear { phase = controller.phase }
            .onReceive(controller.$phase) { phase = $0 }
    }

    private var icon: String {
        switch phase {
        case .recording:
            "waveform.circle.fill"
        case .transcribing:
            "ellipsis.circle.fill"
        case .failure:
            "exclamationmark.circle.fill"
        default:
            "waveform.circle"
        }
    }
}

private struct MenuBarContent: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button(recordingTitle) {
            appModel.voice.toggleRecording()
        }
        .disabled(appModel.voice.phase == .transcribing)

        if case .failure(_, let canRetry) = appModel.voice.phase, canRetry {
            Button(L10n.text("action.retry")) {
                appModel.voice.retryTranscription()
            }
        }

        Divider()
        Button(L10n.text("menu.open")) {
            openWindow(id: "main")
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
        Button(L10n.text("menu.settings")) {
            openSettings()
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
        Divider()
        Button(L10n.text("menu.quit")) {
            appModel.voice.cancelAndReset()
            NSApplication.shared.terminate(nil)
        }
    }

    private var recordingTitle: String {
        if case .recording = appModel.voice.phase {
            L10n.text("action.stop_recording")
        } else {
            L10n.text("action.start_recording")
        }
    }
}
