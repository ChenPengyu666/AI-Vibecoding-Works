import Foundation

/// 用户设置管理器
final class SettingsManager {
    static let shared = SettingsManager()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let storageDays = "com.clipboardhistory.storage_days"
        static let runMode = "com.clipboardhistory.run_mode"
        static let launchAtLogin = "com.clipboardhistory.launch_at_login"
        static let showDockIcon = "com.clipboardhistory.show_dock_icon"
        static let keyboardShortcut = "com.clipboardhistory.keyboard_shortcut"
    }

    enum RunMode: String, CaseIterable {
        case menuBar
        case dock
        case both

        var displayName: String {
            switch self {
            case .menuBar: return "仅菜单栏"
            case .dock: return "仅 Dock"
            case .both: return "两者都显示"
            }
        }
    }

    /// 存储期限（天数），默认 3 天
    var storageDays: Int {
        get {
            let value = defaults.integer(forKey: Keys.storageDays)
            return value > 0 ? value : 3
        }
        set { defaults.set(newValue, forKey: Keys.storageDays) }
    }

    /// 存储期限对应的秒数
    var storageSeconds: TimeInterval {
        TimeInterval(storageDays) * 24 * 60 * 60
    }

    /// 运行模式，默认两者都显示
    var runMode: RunMode {
        get {
            guard let raw = defaults.string(forKey: Keys.runMode),
                  let mode = RunMode(rawValue: raw) else {
                return .both
            }
            return mode
        }
        set { defaults.set(newValue.rawValue, forKey: Keys.runMode) }
    }

    /// 是否在 Dock 栏显示图标，默认 true
    var showDockIcon: Bool {
        get {
            if defaults.object(forKey: Keys.showDockIcon) == nil {
                return true
            }
            return defaults.bool(forKey: Keys.showDockIcon)
        }
        set { defaults.set(newValue, forKey: Keys.showDockIcon) }
    }

    /// 快捷键字符串，默认 "command+shift+v"
    var keyboardShortcut: String {
        get {
            defaults.string(forKey: Keys.keyboardShortcut) ?? "command+shift+v"
        }
        set { defaults.set(newValue, forKey: Keys.keyboardShortcut) }
    }

    /// 是否开机启动，默认 true
    var launchAtLogin: Bool {
        get {
            if defaults.object(forKey: Keys.launchAtLogin) == nil {
                return true
            }
            return defaults.bool(forKey: Keys.launchAtLogin)
        }
        set { defaults.set(newValue, forKey: Keys.launchAtLogin) }
    }

    private init() {}
}
