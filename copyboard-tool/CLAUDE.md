# CLAUDE.md — ClipboardHistory 项目指引

## 项目概述

**ClipboardHistory** 是一款 macOS 本地剪贴板历史管理工具。自动记录文字和图片复制内容，支持浏览、搜索、置顶、删除，可设置 1/3/5 天存储期限。技术栈：Swift 5.9 + SwiftUI + GRDB(SQLite)，最低 macOS 14。

---

## 文档索引

所有项目标准文件位于 `docs/` 文件夹：

| 文件 | 路径 | 用途 |
|------|------|------|
| 需求规格 | [docs/requirements.md](docs/requirements.md) | 功能需求 F1-F9、非功能需求 NF1-NF4 |
| 技术规范 | [docs/technical-spec.md](docs/technical-spec.md) | 架构(MVVM)、数据流、数据库表结构、权限、错误处理 |
| 设计规范 | [docs/design-spec.md](docs/design-spec.md) | 配色、尺寸、卡片样式、图标、空状态、交互 |
| 执行计划 | [docs/execution-plan.md](docs/execution-plan.md) | 分 6 个阶段的详细任务清单和验证标准 |

## 开发日志索引

| 文件 | 路径 | 用途 |
|------|------|------|
| 完成日志 | [dev-logs/CHANGELOG.md](dev-logs/CHANGELOG.md) | 记录每次开发完成的事项和日期 |
| 待办清单 | [dev-logs/TODO.md](dev-logs/TODO.md) | 当前阶段的待办和未来阶段的规划 |

---

## 工作流程

### 每次开发前的标准流程

1. **读取待办清单** — 打开 `dev-logs/TODO.md`，确认当前阶段和下一个任务
2. **回顾相关文档** — 根据任务类型查看对应规范文件
   - UI 相关 → `docs/design-spec.md`
   - 数据/架构相关 → `docs/technical-spec.md`
   - 功能定义 → `docs/requirements.md`
3. **编码实现** — 按 `docs/execution-plan.md` 中当前阶段的任务顺序执行
4. **验证** — 对照执行计划中的阶段验证标准
5. **更新日志** — 在 `dev-logs/CHANGELOG.md` 记录完成内容，更新 `dev-logs/TODO.md` 勾选完成项

### 阶段推进规则

- **一个阶段一个阶段做**，不跳阶段，不跨阶段混合开发
- **当前阶段所有任务完成并验证后**，才能开始下一阶段
- **每个阶段结束**，向用户汇报完成情况，等待确认后再进入下一阶段
- **遇到设计规范未覆盖的 UI 决策**，选择最简洁的方案，并在 CHANGELOG 中记录

---

## 代码规范

### 命名约定
- Swift 类型名：大驼峰 `ClipboardMonitor`
- 变量/函数名：小驼峰 `loadItems()`
- 常量：小驼峰 `defaultStorageDays`
- 文件命名：与主要类型名一致 `ClipboardItem.swift`

### 文件组织
- 每个 Swift 文件只包含一个主要类型定义
- 文件夹严格按照 MVVM 分层：`App/`, `Models/`, `Services/`, `ViewModels/`, `Views/`

### 注释规范
- 公共接口（public/internal）使用 `///` 文档注释
- 复杂逻辑使用 `//` 行注释解释意图
- MARK 分隔代码段：`// MARK: - Properties`

### SwiftUI 规范
- View 结构体遵循 `View` 协议
- 复杂 View 提取子组件，避免 body 超过 50 行
- 颜色使用 Asset Catalog 管理（`Color("accent")`），不硬编码 hex
- 字符串使用 `LocalizedStringKey`（预留国际化）

### 依赖注入
- Service 层使用单例模式 `static let shared = ...`
- ViewModel 通过 `@Environment` 或构造函数注入 Service

---

## 禁止事项

- ❌ **不要一次性做多个阶段的任务** — 保持专注，逐步推进
- ❌ **不要跳过验证步骤** — 每个阶段结束后必须验证
- ❌ **不要修改 docs/ 规范文件** — 除非用户明确要求变更需求
- ❌ **不要引入额外的第三方依赖** — 除 GRDB 外不添加其他库
- ❌ **不要联网** — 项目不涉及任何网络功能
- ❌ **不要创建不必要的抽象层** — 保持简单，一个功能一个文件
- ❌ **不要在没有确认的情况下删除用户数据** — 清理逻辑需严格按存储期限执行

---

## 架构速查

```
ClipboardHistory/
├── App/                           # 应用入口
│   ├── ClipboardHistoryApp.swift   # @main App，模式切换
│   └── AppDelegate.swift           # NSStatusBar 菜单栏管理
├── Models/
│   └── ClipboardItem.swift         # Codable + FetchableRecord
├── Services/
│   ├── ClipboardMonitor.swift      # Timer 0.5s 轮询 NSPasteboard
│   ├── DataStore.swift             # GRDB 数据库操作 + 过期清理
│   └── SettingsManager.swift       # UserDefaults 封装
├── ViewModels/
│   └── ClipboardViewModel.swift    # @Observable，状态管理
├── Views/
│   ├── ContentView.swift           # 主布局
│   ├── ClipboardCardView.swift     # 卡片组件
│   ├── SearchBarView.swift         # 搜索栏
│   ├── ImagePreviewView.swift      # 图片预览
│   ├── SettingsView.swift          # 设置面板
│   └── MenuBarView.swift           # 菜单栏 Popover
└── Resources/
    └── Assets.xcassets             # 图标和颜色
```

---

*此文件由用户和管理员共同维护，AI 助手应始终遵循以上指引。*
