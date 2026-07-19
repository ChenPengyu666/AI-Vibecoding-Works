import SwiftUI
import ServiceManagement

/// 设置面板
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var storageDays: Int = SettingsManager.shared.storageDays
    @State private var runMode: SettingsManager.RunMode = SettingsManager.shared.runMode
    @State private var showDockIcon: Bool = SettingsManager.shared.showDockIcon
    @State private var launchAtLogin: Bool = SettingsManager.shared.launchAtLogin
    @State private var keyboardShortcut: String = SettingsManager.shared.keyboardShortcut
    @State private var bulkDeleteRange: BulkDeleteRange = .oneDay
    @State private var showDeleteConfirmation = false
    @State private var pendingDeleteCount = 0

    private let dayOptions = [1, 3, 5]

    /// 批量删除时间范围
    private enum BulkDeleteRange: String, CaseIterable {
        case thirtyMinutes
        case twoHours
        case oneDay
        case all

        var displayName: String {
            switch self {
            case .thirtyMinutes: return "30 分钟前"
            case .twoHours: return "2 小时前"
            case .oneDay: return "1 天前"
            case .all: return "全部"
            }
        }

        var seconds: TimeInterval? {
            switch self {
            case .thirtyMinutes: return 1800
            case .twoHours: return 7200
            case .oneDay: return 86400
            case .all: return nil
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text("设置")
                    .font(.headline)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)

            Divider()

            // 设置内容
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // 运行模式
                    VStack(alignment: .leading, spacing: 8) {
                        Text("运行模式")
                            .font(.system(size: 13, weight: .medium))
                        Picker("", selection: $runMode) {
                            ForEach(SettingsManager.RunMode.allCases, id: \.self) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }

                    // Dock 栏图标
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Dock 栏图标")
                            .font(.system(size: 13, weight: .medium))
                        Toggle(isOn: $showDockIcon) {
                            Text(showDockIcon ? "已开启 — 在 Dock 栏显示应用图标" : "已关闭")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .toggleStyle(.switch)
                    }

                    // 存储期限
                    VStack(alignment: .leading, spacing: 8) {
                        Text("存储期限")
                            .font(.system(size: 13, weight: .medium))
                        Picker("", selection: $storageDays) {
                            ForEach(dayOptions, id: \.self) { days in
                                Text("\(days) 天").tag(days)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }

                    // 快捷键
                    ShortcutSettingRow(shortcut: $keyboardShortcut)

                    // 清理历史
                    VStack(alignment: .leading, spacing: 8) {
                        Text("清理历史")
                            .font(.system(size: 13, weight: .medium))

                        Picker("", selection: $bulkDeleteRange) {
                            ForEach(BulkDeleteRange.allCases, id: \.self) { range in
                                Text(range.displayName).tag(range)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()

                        Button(action: {
                            if bulkDeleteRange == .all {
                                pendingDeleteCount = DataStore.shared.countAll()
                            } else if let seconds = bulkDeleteRange.seconds {
                                pendingDeleteCount = DataStore.shared.countOlderThan(seconds: seconds)
                            }
                            showDeleteConfirmation = true
                        }) {
                            Text("清理")
                                .font(.system(size: 12, weight: .medium))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(bulkDeleteRange == .all ? .red : .accentColor)
                        .alert("确认清理", isPresented: $showDeleteConfirmation) {
                            Button("取消", role: .cancel) { }
                            Button("确认清理", role: .destructive) {
                                if bulkDeleteRange == .all {
                                    _ = DataStore.shared.deleteAll()
                                } else if let seconds = bulkDeleteRange.seconds {
                                    _ = DataStore.shared.deleteOlderThan(seconds: seconds)
                                }
                                NotificationCenter.default.post(name: .clipboardDataChanged, object: nil)
                            }
                        } message: {
                            if pendingDeleteCount == 0 {
                                Text("没有需要清理的记录。")
                            } else if bulkDeleteRange == .all {
                                Text("将删除全部 \(pendingDeleteCount) 条历史记录，包括置顶条目。此操作不可撤销。")
                            } else {
                                Text("将删除 \(pendingDeleteCount) 条 \(bulkDeleteRange.displayName)的历史记录（置顶条目除外）。此操作不可撤销。")
                            }
                        }
                    }

                    // 开机启动
                    VStack(alignment: .leading, spacing: 8) {
                        Text("开机启动")
                            .font(.system(size: 13, weight: .medium))
                        Toggle(isOn: $launchAtLogin) {
                            Text(launchAtLogin ? "已开启 — 登录时自动启动" : "已关闭")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .toggleStyle(.switch)
                    }

                    Divider()

                    // 关于
                    VStack(alignment: .leading, spacing: 4) {
                        Text("关于 ClipboardHistory")
                            .font(.system(size: 13, weight: .medium))
                        Text("版本 1.1.0")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Text("一款简洁的 Mac 剪贴板历史管理工具")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }

            Spacer()
        }
        .frame(width: 320, height: 480)
        .onChange(of: storageDays) { _, newValue in
            SettingsManager.shared.storageDays = newValue
        }
        .onChange(of: runMode) { _, newValue in
            SettingsManager.shared.runMode = newValue
            NotificationCenter.default.post(name: .runModeChanged, object: nil)
        }
        .onChange(of: showDockIcon) { _, newValue in
            SettingsManager.shared.showDockIcon = newValue
            NotificationCenter.default.post(name: .dockIconChanged, object: nil)
        }
        .onChange(of: launchAtLogin) { _, newValue in
            SettingsManager.shared.launchAtLogin = newValue
            if newValue {
                try? SMAppService.mainApp.register()
            } else {
                try? SMAppService.mainApp.unregister()
            }
        }
        .onChange(of: keyboardShortcut) { _, newValue in
            SettingsManager.shared.keyboardShortcut = newValue
            NotificationCenter.default.post(name: .shortcutChanged, object: nil)
        }
    }
}

// MARK: - 通知名称

extension Notification.Name {
    static let runModeChanged = Notification.Name("com.clipboardhistory.runModeChanged")
    static let dockIconChanged = Notification.Name("com.clipboardhistory.dockIconChanged")
    static let shortcutChanged = Notification.Name("com.clipboardhistory.shortcutChanged")
}

#Preview {
    SettingsView()
}
