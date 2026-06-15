import AppKit
import Carbon
import SwiftUI

struct HotKeyRecorderView: View {
    @Binding var hotKey: HotKey
    @State private var isListening = false
    @State private var monitor: Any?

    var body: some View {
        Button {
            isListening ? stopListening() : startListening()
        } label: {
            HStack {
                Image(systemName: "keyboard")
                Text(isListening ? L10n.text("hotkey.press") : hotKey.displayValue)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
            }
            .foregroundStyle(isListening ? MacVoiceTheme.cyan : .primary)
            .padding(.horizontal, 12)
            .frame(minWidth: 132, minHeight: 34)
            .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
        .onDisappear { stopListening() }
    }

    private func startListening() {
        isListening = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let modifiers = carbonModifiers(from: flags)
            guard modifiers != 0 else { return nil }
            hotKey = HotKey(keyCode: UInt32(event.keyCode), modifiers: modifiers)
            stopListening()
            return nil
        }
    }

    private func stopListening() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        isListening = false
    }

    private func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var value: UInt32 = 0
        if flags.contains(.command) { value |= UInt32(cmdKey) }
        if flags.contains(.option) { value |= UInt32(optionKey) }
        if flags.contains(.shift) { value |= UInt32(shiftKey) }
        if flags.contains(.control) { value |= UInt32(controlKey) }
        return value
    }
}
