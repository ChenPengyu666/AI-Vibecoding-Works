# 执行计划

## 概述

分 6 个阶段（0-5），每个阶段产出可验证的结果，完成后确认再进入下一阶段。

---

## 第 0 阶段：项目初始化 ✅ 当前

**目标**：搭建项目管理基础设施和开发环境。

| # | 任务 | 产出 | 状态 |
|---|------|------|------|
| 0.1 | 创建项目文档结构 | `docs/` 文件夹 + 4 份文档 | 进行中 |
| 0.2 | 创建开发日志 | `dev-logs/` + CHANGELOG.md + TODO.md | 待办 |
| 0.3 | 创建 CLAUDE.md | 项目根目录 `CLAUDE.md` | 待办 |
| 0.4 | 创建 Xcode 项目 | `ClipboardHistory.xcodeproj` | 待办 |
| 0.5 | 配置 GRDB 依赖 | Package.resolved 确认依赖拉取 | 待办 |

**验证**：Xcode 项目可编译通过（空白 App 可运行）

---

## 第 1 阶段：数据层

**目标**：完成数据模型和存储层，可通过单元测试验证。

| # | 任务 | 产出 | 关键文件 |
|---|------|------|---------|
| 1.1 | ClipboardItem 模型 | 数据模型定义 | `Models/ClipboardItem.swift` |
| 1.2 | DataStore 实现 | CRUD + 清理 | `Services/DataStore.swift` |
| 1.3 | SettingsManager | 配置读写 | `Services/SettingsManager.swift` |
| 1.4 | 单元测试 | 测试通过 | `ClipboardHistoryTests/` |

**验证**：运行单元测试，确认插入/查询/删除/清理均正确

---

## 第 2 阶段：剪贴板监听

**目标**：自动捕获系统剪贴板变化并存入数据库。

| # | 任务 | 产出 | 关键文件 |
|---|------|------|---------|
| 2.1 | ClipboardMonitor | 监听 + 读写 + 去重 | `Services/ClipboardMonitor.swift` |
| 2.2 | 集成到 App 启动 | App 启动时开始监听 | `App/ClipboardHistoryApp.swift` |
| 2.3 | 手动测试 | 复制文字和图片确认入库 | - |

**验证**：运行 App，复制内容后查询数据库确认记录存在

---

## 第 3 阶段：主界面

**目标**：完成卡片列表 UI、搜索、操作交互。

| # | 任务 | 产出 | 关键文件 |
|---|------|------|---------|
| 3.1 | ClipboardViewModel | 数据绑定 + 操作逻辑 | `ViewModels/ClipboardViewModel.swift` |
| 3.2 | ContentView | 主布局（列表+工具栏） | `Views/ContentView.swift` |
| 3.3 | ClipboardCardView | 卡片组件（3 种样式） | `Views/ClipboardCardView.swift` |
| 3.4 | SearchBarView | 搜索框 + 实时过滤 | `Views/SearchBarView.swift` |
| 3.5 | ImagePreviewView | 图片大图弹窗 | `Views/ImagePreviewView.swift` |

**验证**：UI 面板可查看历史、搜索、置顶、删除、点击复制

---

## 第 4 阶段：菜单栏 + 设置

**目标**：菜单栏集成、设置面板、模式切换、开机启动。

| # | 任务 | 产出 | 关键文件 |
|---|------|------|---------|
| 4.1 | MenuBarView | Popover 容器 | `Views/MenuBarView.swift` |
| 4.2 | AppDelegate | 菜单栏状态 + 图标 | `App/AppDelegate.swift` |
| 4.3 | 模式切换逻辑 | 菜单栏/Dock/两者 | `App/ClipboardHistoryApp.swift` |
| 4.4 | SettingsView | 设置面板 UI | `Views/SettingsView.swift` |
| 4.5 | 开机启动 | SMAppService 集成 | `Services/SettingsManager.swift` |

**验证**：菜单栏图标可点击弹出面板，设置可修改并实时生效，重启后自动启动

---

## 第 5 阶段：收尾与测试

**目标**：权限引导、端到端测试、打包。

| # | 任务 | 产出 | 关键文件 |
|---|------|------|---------|
| 5.1 | 权限引导页 | 首次启动友好引导 | 新增 View |
| 5.2 | 按验证清单逐项测试 | 10 项测试通过 | - |
| 5.3 | 修复测试中发现的问题 | Bug 修复 | 相关文件 |
| 5.4 | 归档导出 .app | 可运行的 .app 包 | - |

**验证**：完整验证清单 10 项全部通过

---

## 验证清单

- [ ] 1. 复制文字 → 面板中显示文字卡片
- [ ] 2. 复制图片 → 面板中显示缩略图卡片
- [ ] 3. 点击文字卡片 → ⌘+V 粘贴内容一致
- [ ] 4. 点击图片卡片 → ⌘+V 粘贴图片一致
- [ ] 5. 搜索关键词 → 列表正确过滤
- [ ] 6. 置顶 → 排到最前，再次点击取消
- [ ] 7. 删除 → 从列表消失
- [ ] 8. 修改存储期 → 过期条目自动清理
- [ ] 9. 菜单栏/Dock 模式切换 → 行为正确
- [ ] 10. 重启 Mac → 自动启动
