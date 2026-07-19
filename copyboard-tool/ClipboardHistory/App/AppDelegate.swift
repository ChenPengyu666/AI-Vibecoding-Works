import AppKit
import SwiftUI
import ServiceManagement

/// 管理菜单栏图标、Popover 和应用生命周期
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var eventMonitor: Any?
    private var shortcutMonitor: Any?

    /// 在启动早期设置 activationPolicy，确保 Dock 图标正确显示
    func applicationWillFinishLaunching(_ notification: Notification) {
        applyRunMode()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 启动剪贴板监听
        ClipboardMonitor.shared.start()

        // 启动时清理过期数据
        let seconds = SettingsManager.shared.storageSeconds
        DataStore.shared.cleanupExpired(olderThan: seconds)

        // 注册开机启动
        if SettingsManager.shared.launchAtLogin {
            try? SMAppService.mainApp.register()
        }

        // 监听运行模式变更
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(runModeChanged),
            name: .runModeChanged,
            object: nil
        )

        // 监听 Dock 图标变更
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(dockIconChanged),
            name: .dockIconChanged,
            object: nil
        )

        // 注册全局快捷键
        registerShortcut()
    }

    func applicationWillTerminate(_ notification: Notification) {
        ClipboardMonitor.shared.stop()
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = shortcutMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    // MARK: - 快捷键

    private func registerShortcut() {
        shortcutMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: .keyDown
        ) { [weak self] event in
            self?.handleShortcut(event)
        }
    }

    private func handleShortcut(_ event: NSEvent) {
        let shortcut = SettingsManager.shared.keyboardShortcut
        guard let (targetModifiers, targetKeyCode) = parseShortcut(shortcut),
              event.modifierFlags == targetModifiers,
              event.keyCode == targetKeyCode else {
            return
        }
        togglePopover()
    }

    /// 将 "command+shift+v" 解析为目标 modifierFlags 和 keyCode
    private func parseShortcut(_ shortcut: String) -> (NSEvent.ModifierFlags, UInt16)? {
        let parts = shortcut.lowercased().components(separatedBy: "+")
        guard parts.count >= 2 else { return nil }

        let keyChar = parts.last?.first?.lowercased() ?? "v"
        let modifiers = parts.dropLast().reduce(into: NSEvent.ModifierFlags()) { flags, part in
            switch part {
            case "command": flags.insert(.command)
            case "shift": flags.insert(.shift)
            case "option": flags.insert(.option)
            case "control": flags.insert(.control)
            default: break
            }
        }

        let keyCode: UInt16
        // US QWERTY 物理 keyCode 映射
        switch keyChar {
        case "a": keyCode = 0;  case "s": keyCode = 1;  case "d": keyCode = 2;
        case "f": keyCode = 3;  case "h": keyCode = 4;  case "g": keyCode = 5;
        case "z": keyCode = 6;  case "x": keyCode = 7;  case "c": keyCode = 8;
        case "v": keyCode = 9;  case "b": keyCode = 11; case "q": keyCode = 12;
        case "w": keyCode = 13; case "e": keyCode = 14; case "r": keyCode = 15;
        case "y": keyCode = 16; case "t": keyCode = 17; case "1": keyCode = 18;
        case "2": keyCode = 19; case "3": keyCode = 20; case "4": keyCode = 21;
        case "6": keyCode = 22; case "5": keyCode = 23; case "=": keyCode = 24;
        case "9": keyCode = 25; case "7": keyCode = 26; case "-": keyCode = 27;
        case "8": keyCode = 28; case "0": keyCode = 29; case "o": keyCode = 31;
        case "u": keyCode = 32; case "[": keyCode = 33; case "i": keyCode = 34;
        case "p": keyCode = 35; case "return": keyCode = 36; case "l": keyCode = 37;
        case "j": keyCode = 38; case "'": keyCode = 39; case "k": keyCode = 40;
        case "_": keyCode = 41; case ";": keyCode = 42; case "\\": keyCode = 43;
        case ",": keyCode = 44; case "/": keyCode = 45; case "n": keyCode = 46;
        case "m": keyCode = 47; case ".": keyCode = 48; case "`": keyCode = 50;
        default: keyCode = 9 // 默认 'V'
        }

        return (modifiers, keyCode)
    }

    // MARK: - 运行模式

    private func applyRunMode() {
        let mode = SettingsManager.shared.runMode

        switch mode {
        case .menuBar:
            setupMenuBar()
            let showDock = SettingsManager.shared.showDockIcon
            NSApp.setActivationPolicy(showDock ? .regular : .accessory)
        case .dock:
            teardownMenuBar()
            NSApp.setActivationPolicy(.regular)
        case .both:
            setupMenuBar()
            NSApp.setActivationPolicy(.regular)
        }
    }

    @objc private func runModeChanged() {
        applyRunMode()
    }

    @objc private func dockIconChanged() {
        applyRunMode()
    }

    // MARK: - 菜单栏

    private func setupMenuBar() {
        guard statusItem == nil else { return }

        // 使用固定长度确保菜单栏图标始终可见，不被压缩隐藏
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            // 创建适配菜单栏尺寸的图标（18x18 是菜单栏标准图标大小）
            if let image = NSImage(
                systemSymbolName: "clipboard",
                accessibilityDescription: "ClipboardHistory"
            ) {
                let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
                let configured = image.withSymbolConfiguration(config)
                button.image = configured
            }
            // 深色/浅色模式自动适配
            button.image?.isTemplate = true
            button.action = #selector(togglePopover)
            button.target = self
            // 设置 tooltip
            button.toolTip = "ClipboardHistory — 剪贴板历史"
        }
    }

    private func teardownMenuBar() {
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
        }
        statusItem = nil
        popover = nil
    }

    // MARK: - Popover

    @objc private func togglePopover() {
        if let popover = popover, popover.isShown {
            popover.performClose(nil)
            return
        }

        // 创建 Popover（首次或重建）
        if popover == nil {
            let popover = NSPopover()
            popover.contentSize = NSSize(width: 380, height: 480)
            popover.behavior = .transient
            popover.contentViewController = NSHostingController(
                rootView: ContentView()
            )
            self.popover = popover
        }

        if let button = statusItem?.button, let popover = popover {
            // 激活 App 确保 Popover 能正常显示
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

            // 监听点击外部区域以关闭 Popover
            if eventMonitor == nil {
                eventMonitor = NSEvent.addGlobalMonitorForEvents(
                    matching: [.leftMouseDown, .rightMouseDown]
                ) { [weak self] event in
                    if let self = self, let popover = self.popover, popover.isShown {
                        popover.performClose(nil)
                    }
                }
            }
        }
    }
}
