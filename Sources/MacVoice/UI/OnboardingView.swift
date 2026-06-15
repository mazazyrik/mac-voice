import AppKit
import AVFoundation
import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var settings: AppSettings

    @State private var step = 0
    @State private var apiKey = ""
    @State private var keyStatus: ValidationStatus = .idle
    @State private var microphoneGranted = false
    @State private var accessibilityGranted = false
    @State private var launchAtLogin = false

    private let stepCount = 9

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 0) {
                progress
                Spacer(minLength: 24)
                content
                    .id(step)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                Spacer(minLength: 24)
                navigation
            }
            .padding(34)
        }
        .preferredColorScheme(.dark)
        .animation(.spring(response: 0.48, dampingFraction: 0.88), value: step)
        .onAppear {
            ensureOnboardingLanguage()
            microphoneGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
            accessibilityGranted = appModel.clipboard.isAccessibilityGranted(prompt: false)
            launchAtLogin = settings.launchAtLoginEnabled
        }
    }

    private var progress: some View {
        HStack(spacing: 7) {
            ForEach(0..<stepCount, id: \.self) { index in
                Capsule()
                    .fill(index <= step ? MacVoiceTheme.gradient : LinearGradient(colors: [.white.opacity(0.13)], startPoint: .leading, endPoint: .trailing))
                    .frame(width: index == step ? 34 : 12, height: 5)
                    .animation(.spring(response: 0.35), value: step)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case 0:
            languageStep
        case 1:
            welcome
        case 2:
            apiKeyStep
        case 3:
            keychainStep
        case 4:
            permissionStep(
                icon: "mic.fill",
                title: L10n.text("onboarding.microphone.title"),
                detail: L10n.text("onboarding.microphone.detail"),
                granted: microphoneGranted,
                actionTitle: L10n.text("onboarding.microphone.action")
            ) {
                microphoneGranted = await appModel.requestMicrophonePermission()
            }
        case 5:
            permissionStep(
                icon: "cursorarrow.click.2",
                title: L10n.text("onboarding.accessibility.title"),
                detail: L10n.text("onboarding.accessibility.detail"),
                granted: accessibilityGranted,
                actionTitle: L10n.text("onboarding.accessibility.action")
            ) {
                accessibilityGranted = appModel.requestAccessibilityPermission()
                if !accessibilityGranted {
                    openAccessibilitySettings()
                }
            }
        case 6:
            hotKeyStep
        case 7:
            testStep
        default:
            finishStep
        }
    }

    private var languageStep: some View {
        OnboardingCard(
            icon: "globe",
            title: L10n.text("onboarding.language.title"),
            detail: L10n.text("onboarding.language.detail")
        ) {
            Picker(L10n.text("settings.language"), selection: $settings.preferredLanguage) {
                Text(L10n.text("onboarding.language.russian")).tag("ru")
                Text(L10n.text("onboarding.language.english")).tag("en")
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 360)
            .accessibilityIdentifier("onboarding-language-picker")
        }
        .accessibilityIdentifier("onboarding-language-step")
    }

    private var welcome: some View {
        VStack(spacing: 25) {
            ZStack {
                Circle()
                    .fill(MacVoiceTheme.gradient)
                    .frame(width: 142, height: 142)
                    .blur(radius: 18)
                    .opacity(0.34)
                Circle()
                    .fill(MacVoiceTheme.gradient)
                    .frame(width: 112, height: 112)
                Image(systemName: "waveform")
                    .font(.system(size: 45, weight: .bold))
            }
            VStack(spacing: 10) {
                Text(L10n.text("onboarding.welcome.title"))
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .accessibilityIdentifier("onboarding-welcome-title")
                Text(L10n.text("onboarding.welcome.detail"))
                    .font(.system(size: 16))
                    .foregroundStyle(MacVoiceTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 520)
            }
        }
    }

    private var apiKeyStep: some View {
        OnboardingCard(
            icon: "key.fill",
            title: L10n.text("onboarding.key.title"),
            detail: L10n.text("onboarding.key.detail")
        ) {
            VStack(spacing: 14) {
                SecureField("sk-...", text: $apiKey)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15, design: .monospaced))
                    .padding(.horizontal, 15)
                    .frame(height: 48)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(keyStatus.color.opacity(0.7), lineWidth: keyStatus == .idle ? 0 : 1)
                    }

                Button {
                    validateKey()
                } label: {
                    HStack {
                        if keyStatus == .validating {
                            ProgressView().controlSize(.small)
                        }
                        Text(keyStatus.actionTitle)
                    }
                }
                .buttonStyle(GradientButtonStyle())
                .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || keyStatus == .validating)

                if case .failed(let message) = keyStatus {
                    Text(message)
                        .font(.system(size: 12))
                        .foregroundStyle(.red.opacity(0.9))
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: 440)
        }
    }

    private var keychainStep: some View {
        OnboardingCard(
            icon: "lock.shield.fill",
            title: L10n.text("onboarding.keychain.title"),
            detail: L10n.text("onboarding.keychain.detail")
        ) {
            VStack(spacing: 14) {
                Label(L10n.text("onboarding.keychain.hint"), systemImage: "checkmark.seal.fill")
                    .font(.system(size: 14, weight: .medium))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
                Text(L10n.text("onboarding.key.security"))
                    .font(.system(size: 12))
                    .foregroundStyle(MacVoiceTheme.secondaryText)
            }
        }
        .accessibilityIdentifier("onboarding-keychain-step")
    }

    private func permissionStep(
        icon: String,
        title: String,
        detail: String,
        granted: Bool,
        actionTitle: String,
        action: @escaping () async -> Void
    ) -> some View {
        OnboardingCard(icon: icon, title: title, detail: detail) {
            if granted {
                Button(action: {}) {
                    Label(L10n.text("permission.granted"), systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(SecondaryButtonStyle())
            } else {
                Button {
                    Task { await action() }
                } label: {
                    Label(actionTitle, systemImage: "arrow.up.right")
                }
                .buttonStyle(GradientButtonStyle())
            }
        }
    }

    private var hotKeyStep: some View {
        OnboardingCard(
            icon: "keyboard",
            title: L10n.text("onboarding.hotkey.title"),
            detail: L10n.text("onboarding.hotkey.detail")
        ) {
            HotKeyRecorderView(hotKey: $settings.hotKey)
            if let error = appModel.hotKeyError {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
            }
        }
    }

    private var testStep: some View {
        OnboardingCard(
            icon: "waveform.badge.mic",
            title: L10n.text("onboarding.test.title"),
            detail: L10n.text("onboarding.test.detail")
        ) {
            VStack(spacing: 14) {
                Button {
                    appModel.voice.toggleRecording()
                } label: {
                    Label(testButtonTitle, systemImage: testButtonIcon)
                }
                .buttonStyle(GradientButtonStyle())
                .disabled(appModel.voice.phase == .transcribing)

                if case .failure(_, let canRetry) = appModel.voice.phase, canRetry {
                    Button {
                        appModel.voice.retryTranscription()
                    } label: {
                        Label(L10n.text("action.retry"), systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
                if !appModel.voice.lastTranscription.isEmpty {
                    Text(appModel.voice.lastTranscription)
                        .font(.system(size: 14))
                        .padding(14)
                        .frame(maxWidth: 430)
                        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
                        .textSelection(.enabled)
                }
            }
        }
    }

    private var finishStep: some View {
        OnboardingCard(
            icon: "checkmark.seal.fill",
            title: L10n.text("onboarding.finish.title"),
            detail: L10n.text("onboarding.finish.detail")
        ) {
            Toggle(L10n.text("settings.launch_at_login"), isOn: $launchAtLogin)
                .toggleStyle(.switch)
                .frame(maxWidth: 310)
        }
    }

    private var navigation: some View {
        HStack {
            if step > 0 {
                Button(L10n.text("action.back")) {
                    step -= 1
                }
                .buttonStyle(SecondaryButtonStyle())
                .accessibilityIdentifier("onboarding-back")
            }
            Spacer()
            Button(step == stepCount - 1 ? L10n.text("action.finish") : L10n.text("action.continue")) {
                advance()
            }
            .buttonStyle(GradientButtonStyle())
            .disabled(!canContinue)
            .accessibilityIdentifier(step == stepCount - 1 ? "onboarding-finish" : "onboarding-continue")
        }
    }

    private var canContinue: Bool {
        switch step {
        case 0:
            settings.preferredLanguage == "ru" || settings.preferredLanguage == "en"
        case 2:
            keyStatus == .success || appModel.hasAPIKey()
        case 4:
            microphoneGranted
        default:
            true
        }
    }

    private var testButtonTitle: String {
        switch appModel.voice.phase {
        case .recording: L10n.text("action.stop_recording")
        case .transcribing: L10n.text("status.transcribing")
        default: L10n.text("action.start_recording")
        }
    }

    private var testButtonIcon: String {
        switch appModel.voice.phase {
        case .recording: "stop.fill"
        case .transcribing: "ellipsis"
        default: "mic.fill"
        }
    }

    private func ensureOnboardingLanguage() {
        guard settings.preferredLanguage == "system" else { return }
        let code = Locale.current.language.languageCode?.identifier ?? "en"
        settings.preferredLanguage = code == "ru" ? "ru" : "en"
    }

    private func validateKey() {
        keyStatus = .validating
        Task {
            do {
                try await appModel.validateAndSaveAPIKey(apiKey)
                keyStatus = .success
                apiKey = ""
            } catch {
                keyStatus = .failed(error.localizedDescription)
            }
        }
    }

    private func advance() {
        if step < stepCount - 1 {
            step += 1
        } else {
            try? settings.setLaunchAtLogin(launchAtLogin)
            settings.onboardingCompleted = true
        }
    }

    private func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}

private struct OnboardingCard<Content: View>: View {
    let icon: String
    let title: String
    let detail: String
    let content: Content

    init(
        icon: String,
        title: String,
        detail: String,
        @ViewBuilder content: () -> Content
    ) {
        self.icon = icon
        self.title = title
        self.detail = detail
        self.content = content()
    }

    var body: some View {
        GlassCard {
            VStack(spacing: 24) {
                ZStack {
                    Circle().fill(MacVoiceTheme.gradient.opacity(0.22))
                    Image(systemName: icon)
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(MacVoiceTheme.gradient)
                }
                .frame(width: 72, height: 72)
                VStack(spacing: 9) {
                    Text(title)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Text(detail)
                        .font(.system(size: 15))
                        .foregroundStyle(MacVoiceTheme.secondaryText)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 510)
                }
                content
            }
            .frame(maxWidth: 610)
            .padding(.vertical, 14)
        }
    }
}

private enum ValidationStatus: Equatable {
    case idle
    case validating
    case success
    case failed(String)

    var actionTitle: String {
        switch self {
        case .validating: L10n.text("key.validating")
        case .success: L10n.text("key.valid")
        default: L10n.text("key.validate")
        }
    }

    var color: Color {
        switch self {
        case .success: .green
        case .failed: .red
        default: .clear
        }
    }
}
