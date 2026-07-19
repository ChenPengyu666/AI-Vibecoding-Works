import AppKit
import SwiftUI

// MARK: - 快捷键格式化

/// 将 "command+shift+v" 格式化为 "⌘+⇧+V"
func formatShortcut(_ shortcut: String) -> String {
    let parts = shortcut.lowercased().components(separatedBy: "+")
    let mapped = parts.map { part in
        switch part {
        case "command": return "⌘"
        case "shift": return "⇧"
        case "option": return "⌥"
        case "control": return "⌃"
        default:
            let char = part.first?.uppercased() ?? "V"
            return String(char)
        }
    }
    return mapped.joined(separator: "+")
}

/// 将 NSEvent.ModifierFlags 转为符号字符串数组
func formatModifierFlags(_ flags: NSEvent.ModifierFlags) -> [String] {
    var parts: [String] = []
    if flags.contains(.command) { parts.append("⌘") }
    if flags.contains(.shift) { parts.append("⇧") }
    if flags.contains(.option) { parts.append("⌥") }
    if flags.contains(.control) { parts.append("⌃") }
    return parts
}

// MARK: - 快捷键设置 UI（在 SettingsView 中使用）

/// 快捷键显示与录制按钮
struct ShortcutSettingRow: View {
    @Binding var shortcut: String
    @State private var isRecording = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("快捷键")
                .font(.system(size: 13, weight: .medium))
            Button(action: { isRecording = true }) {
                HStack {
                    Text(formatShortcut(shortcut))
                        .font(.system(size: 13))
                    Spacer()
                    Image(systemName: "keyboard")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(white: 0.95))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $isRecording) {
            KeyCaptureSheet(shortcut: $shortcut)
                .frame(width: 240, height: 120)
        }
    }
}

/// 快捷键捕获弹窗
struct KeyCaptureSheet: View {
    @Binding var shortcut: String
    @Environment(\.dismiss) private var dismiss
    @State private var displayText: String = "⌘ + ⇧ + V"

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            VStack(spacing: 8) {
                Text(displayText)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.accent)
                    .monospaced()
                Text("按下新的快捷键组合，或按 Esc 取消")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(20)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .overlay {
            KeyCaptureViewRep(
                onCapture: { modFlags, keyCode, char in
                    let parts = formatModifierFlags(modFlags) + [char]
                    let s = parts.joined(separator: "+")
                    shortcut = s
                    displayText = formatShortcut(s)
                    dismiss()
                },
                onCancel: { dismiss() }
            )
        }
    }
}
