import AppKit
import SwiftData
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.modelContext) private var modelContext
    @Query private var history: [TranscriptionRecord]

    @State private var newAPIKey = ""
    @State private var keyMessage = ""
    @State private var isSavingKey = false
    @State private var launchAtLogin = false

    var body: some View {
        TabView {
            general
                .tabItem { Label(L10n.text("settings.general"), systemImage: "slider.horizontal.3") }
            openAI
                .tabItem { Label("OpenAI", systemImage: "sparkles") }
            dictation
                .tabItem { Label(L10n.text("settings.dictation"), systemImage: "waveform") }
            privacy
                .tabItem { Label(L10n.text("settings.privacy"), systemImage: "hand.raised.fill") }
        }
        .padding(20)
        .onAppear { launchAtLogin = settings.launchAtLoginEnabled }
    }

    private var general: some View {
        Form {
            Section(L10n.text("settings.behavior")) {
                Toggle(L10n.text("settings.auto_paste"), isOn: $settings.autoPaste)
                    .accessibilityIdentifier("auto-paste-toggle")
                Toggle(L10n.text("settings.sounds"), isOn: $settings.soundEnabled)
                Toggle(L10n.text("settings.launch_at_login"), isOn: Binding(
                    get: { launchAtLogin },
                    set: { value in
                        do {
                            try settings.setLaunchAtLogin(value)
                            launchAtLogin = value
                        } catch {
                            keyMessage = error.localizedDescription
                        }
                    }
                ))
            }
            Section(L10n.text("settings.hotkey")) {
                HStack {
                    Text(L10n.text("settings.toggle_recording"))
                    Spacer()
                    HotKeyRecorderView(hotKey: $settings.hotKey)
                }
                if let error = appModel.hotKeyError {
                    Text(error).foregroundStyle(.red)
                }
            }
            Section(L10n.text("settings.language")) {
                Picker(L10n.text("settings.language"), selection: $settings.preferredLanguage) {
                    Text(L10n.text("language.system")).tag("system")
                    Text("Русский").tag("ru")
                    Text("English").tag("en")
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("settings-language-picker")
            }
        }
        .formStyle(.grouped)
    }

    private var openAI: some View {
        Form {
            Section("OpenAI API") {
                HStack {
                    Label(
                        appModel.hasAPIKey() ? L10n.text("key.saved") : L10n.text("key.missing"),
                        systemImage: appModel.hasAPIKey() ? "checkmark.circle.fill" : "exclamationmark.circle"
                    )
                    .foregroundStyle(appModel.hasAPIKey() ? .green : .orange)
                    Spacer()
                    if appModel.hasAPIKey() {
                        Button(L10n.text("action.remove"), role: .destructive) {
                            try? appModel.removeAPIKey()
                        }
                    }
                }
                SecureField(L10n.text("key.new"), text: $newAPIKey)
                    .textFieldStyle(.roundedBorder)
                Button {
                    saveKey()
                } label: {
                    if isSavingKey {
                        ProgressView().controlSize(.small)
                    } else {
                        Text(L10n.text("key.validate_save"))
                    }
                }
                .disabled(newAPIKey.isEmpty || isSavingKey)
                if !keyMessage.isEmpty {
                    Text(keyMessage)
                        .font(.caption)
                        .foregroundStyle(keyMessage == L10n.text("key.saved") ? .green : .secondary)
                }
            }
            Section(L10n.text("settings.model")) {
                LabeledContent(L10n.text("settings.transcription_model"), value: "gpt-4o-transcribe")
                Text(L10n.text("settings.model_detail"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var dictation: some View {
        Form {
            Section(L10n.text("settings.vocabulary")) {
                TextEditor(text: $settings.customVocabulary)
                    .font(.system(.body, design: .monospaced))
                    .frame(height: 150)
                Text(L10n.text("settings.vocabulary_detail"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section(L10n.text("settings.permissions")) {
                Button(L10n.text("settings.request_microphone")) {
                    Task { _ = await appModel.requestMicrophonePermission() }
                }
                Button(L10n.text("settings.request_accessibility")) {
                    _ = appModel.requestAccessibilityPermission()
                }
            }
        }
        .formStyle(.grouped)
    }

    private var privacy: some View {
        Form {
            Section(L10n.text("settings.history")) {
                Toggle(L10n.text("settings.save_history"), isOn: $settings.historyEnabled)
                Text(L10n.text("settings.history_detail"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button(L10n.text("settings.clear_history"), role: .destructive) {
                    history.forEach { modelContext.delete($0) }
                    try? modelContext.save()
                }
                .disabled(history.isEmpty)
            }
            Section(L10n.text("settings.data")) {
                Text(L10n.text("settings.data_detail"))
                    .font(.callout)
                Link(
                    L10n.text("settings.openai_privacy"),
                    destination: URL(string: "https://openai.com/policies/privacy-policy/")!
                )
            }
            Section {
                Button(L10n.text("settings.show_onboarding")) {
                    settings.onboardingCompleted = false
                }
            }
        }
        .formStyle(.grouped)
    }

    private func saveKey() {
        isSavingKey = true
        keyMessage = ""
        Task {
            do {
                try await appModel.validateAndSaveAPIKey(newAPIKey)
                newAPIKey = ""
                keyMessage = L10n.text("key.saved")
            } catch {
                keyMessage = error.localizedDescription
            }
            isSavingKey = false
        }
    }
}
