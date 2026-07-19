# 开发日志 - 已完成事项

## 第 0-3 阶段 ✅
项目初始化、数据层（SQLite3）、剪贴板监听、主界面 UI 全部完成。
详见之前的日志。

## 第 1.1 版本更新 ✅ — 自定义快捷键 + Dock 图标修复（2026-06-12）

### Bug 修复
- **Dock 栏图标不显示自定义图标**：
  - 删除冗余的 `AppIcon.icns` 文件（1.3MB），从 Xcode 项目移除 4 处引用
  - 移除 `Info.plist` 中冲突的 `CFBundleIconFile` 键（与 `ASSETCATALOG_COMPILER_APPICON_NAME` 冲突导致系统查找不存在的 .icns 文件）
  - 重新生成全部 10 个图标尺寸（此前图片像素尺寸全部翻倍，如 16x16 实际是 32x32）
  - 修复 `generate-icons.swift`：改用 NSBitmapImageRep 精确控制像素 + sips 缩放

### 新增功能：自定义快捷键
- 默认快捷键 `⌘+⇧+V`，可在设置面板中自定义
- 使用 `addGlobalMonitorForEvents` 实现全局键盘监听，App 在后台也能响应
- 设置面板新增「快捷键录制」功能：点击 → 捕获按键 → 立即生效
- 快捷键存储格式：`"command+shift+v"` 风格字符串，兼容现有代码模式

### 新增文件
- `Views/ShortcutSettingRow.swift` — 快捷键设置行 UI + `formatShortcut` 工具函数
- `Views/KeyCaptureView.swift` — NSViewRepresentable 快捷键捕获组件

### 修改文件
- `App/AppDelegate.swift` — 新增 `shortcutMonitor` 全局 keyDown 监听 + `parseShortcut()` + `handleShortcut()`
- `Services/SettingsManager.swift` — 新增 `keyboardShortcut` 属性
- `Views/SettingsView.swift` — 新增快捷键设置 UI + `.shortcutChanged` 通知
- `ClipboardHistory.xcodeproj/project.pbxproj` — 移除 AppIcon.icns 引用 + 新增 2 个文件引用
- `ClipboardHistory/Resources/Info.plist` — 版本 1.0→1.1, build 1→2
- `scripts/create-dmg.sh` — VERSION 1.0.0→1.1.0

### 删除文件
- `ClipboardHistory/Resources/AppIcon.icns` — 1.3MB 冗余图标文件
- 编译通过 ✅

## 第 4 阶段 ✅ — 菜单栏 + 设置（2026-06-12）

### Bug 修复
- 修复 `.fileNames` PasteboardType 编译错误
- 修复图片捕获：文件 URL 读取改用 `pasteboardItems` 遍历

### 新增文件
- `Views/MenuBarView.swift` — 菜单栏 Popover 容器
- `Views/SettingsView.swift` — 设置面板（运行模式、存储期限、开机启动）

### 修改文件
- `App/AppDelegate.swift` — NSStatusBar 菜单栏图标 + NSPopover + SMAppService
- `Views/ContentView.swift` — 底部工具栏增加 ⚙️ 设置按钮
- `App/ClipboardHistoryApp.swift` — `.runModeChanged` 通知定义

### 功能
- 菜单栏模式：右上角剪贴板图标，点击弹出面板
- Dock 模式：独立窗口
- 两者模式：菜单栏 + Dock 同时显示
- 设置面板：运行模式切换、存储期限（1/3/5天）、开机启动开关
- 模式切换实时生效
- 编译通过 ✅

## 第 4.5 阶段 ✅ — Bug 修复 + 文件格式扩展（2026-06-12）

### Bug 修复
- **菜单栏 Popover 不显示**：`togglePopover()` 中添加 `NSApp.activate(ignoringOtherApps: true)` 确保 Popover 能在后台模式下正常弹出
- **复制图片文件后文件名消失**：图片捕获时保留原始文件名，卡片显示文件名而非"图片"

### 新增功能：通用文件格式支持
- 新增 `file` ItemType，支持复制任意文件类型
- 支持格式：Word(.doc/.docx)、Excel(.xls/.xlsx)、PPT(.ppt/.pptx)、PDF、视频(.mp4/.mov/...)、音频(.mp3/.wav/...)、压缩包(.zip/.rar/...)、代码文件等
- 每种文件类型有独立的 SF Symbol 图标和颜色标识
- 文件卡片显示原始文件名 + 文件大小 + 扩展名标签
- 点击文件卡片 → 复制文件引用到剪贴板（可在 Finder 中 ⌘+V 粘贴）
- "在 Finder 中显示"按钮快速定位原始文件

### 模型扩展
- `ClipboardItem` 新增 `file` ItemType、`fileName`、`filePath` 属性
- 数据库新增 `file_path`、`file_name` 列（自动迁移旧表）
- 图片条目工厂方法新增 `fileName` 参数

### 文件变更
- `Models/ClipboardItem.swift` — 新增 file 类型 + fileName/filePath 字段
- `Services/ClipboardMonitor.swift` — 重构为通用文件 URL 捕获，保留原始文件名
- `Services/DataStore.swift` — 新增列 + 迁移逻辑 + 行映射更新
- `ViewModels/ClipboardViewModel.swift` — file 类型复制/预览/在 Finder 中打开
- `Views/ClipboardCardView.swift` — 文件图标系统（按扩展名分类）+ 文件名显示
- `Views/ContentView.swift` — 传递 onOpenInFinder 回调
- 编译通过 ✅

## 第 4.6 阶段 ✅ — 菜单栏图标优化 + 自动滚动（2026-06-12）

### 菜单栏图标优化
- 改用 `NSStatusItem.squareLength` 固定宽度，避免被系统压缩隐藏
- 图标使用 `SymbolConfiguration(pointSize: 16)` 适配菜单栏 18×18 标准尺寸
- 设置 `isTemplate = true` 支持系统深色/浅色模式自动适配
- 添加 `toolTip` 提示文字

### 自动滚动到顶部
- 监听 `.clipboardDataChanged` 通知，新复制项到达时自动将列表滚到最顶端
- 使用 `ScrollViewReader.scrollTo(id, anchor: .top)` 配合动画平滑滚动

### 修改文件
- `App/AppDelegate.swift` — 菜单栏图标固定长度 + 尺寸适配 + 模板模式
- `Views/ContentView.swift` — `.onReceive` 中添加自动滚到顶部逻辑
- 编译通过 ✅

## 第 5 阶段 ✅ — 收尾与发布（2026-06-12）

### DMG 打包
- 编写 `scripts/create-dmg.sh` 一键打包脚本
- 自动编译 Release → 生成 DMG → 设置 Finder 窗口布局
- DMG 包含 ClipboardHistory.app + /Applications 快捷方式
- 输出: `build/ClipboardHistory_v1.0.0.dmg`（185KB）

### 项目完成清单
- [x] 文字/图片/文件剪贴板监听
- [x] 卡片列表（时间倒序、置顶优先）
- [x] 实时搜索
- [x] 置顶 / 删除
- [x] 点击卡片复制到剪贴板
- [x] 图片缩略图 + 大图预览
- [x] 文件格式支持（Word/视频/PDF/压缩包等 40+ 种扩展名）
- [x] 菜单栏图标 + Popover 面板
- [x] 设置面板（运行模式/存储期限/开机启动）
- [x] Dock/菜单栏模式切换
- [x] 新复制自动滚到顶部
- [x] DMG 打包发布

### 最终文件统计
- Swift 源码: 14 个文件
- 无外部依赖
- 最低 macOS 14

## 第 6 阶段 ✅ — Dock 栏图标开关 + 批量清理历史（2026-06-12）

### 新增功能：Dock 栏图标独立开关
- 设置面板新增 "Dock 栏图标" 开关，独立于运行模式
- 仅在"仅菜单栏"模式下生效：开启后在菜单栏模式也显示 Dock 图标
- "仅 Dock"和"两者都显示"模式下 Dock 图标始终可见
- 实时切换，无需重启

### 新增功能：批量清理历史记录
- 设置面板新增 "清理历史" 区域
- 四个时间范围选项：30 分钟前 / 2 小时前 / 1 天前 / 全部
- 时间范围删除时保留置顶条目，"全部"则包含置顶
- 删除前显示确认弹窗，标明待删除条目数量和影响范围
- 自动清理关联的图片文件，不留残留

### 修改文件
- `Services/SettingsManager.swift` — 新增 `showDockIcon` 属性
- `Services/DataStore.swift` — 新增 `countOlderThan`、`countAll`、`deleteOlderThan`、`deleteAll` 四个方法
- `ViewModels/ClipboardViewModel.swift` — 新增四个批量删除包装方法
- `App/AppDelegate.swift` — `applyRunMode()` 支持 Dock 图标开关 + 监听 `.dockIconChanged`
- `Views/SettingsView.swift` — 新增 Dock 栏图标区域 + 清理历史区域 + 确认弹窗 + 高度增至 480
- 编译通过 ✅

### 新增功能：自定义应用图标（2026-06-12）
- 生成美观的自定义应用图标替代 Xcode 默认图标
- 设计：深蓝→浅蓝渐变圆角矩形背景 + 白色剪贴板图标
- 覆盖全部尺寸：16x16 ~ 1024x1024（含 Retina @2x）
- `scripts/generate-icons.swift` — 图标生成脚本，可随时修改重新生成
- Info.plist 添加 `CFBundleIconFile = AppIcon`
- 编译通过 ✅
