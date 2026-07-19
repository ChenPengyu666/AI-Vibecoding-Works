# 技术规范

## 技术栈

| 层面 | 选择 | 版本 |
|------|------|------|
| 语言 | Swift | 5.9+ |
| UI 框架 | SwiftUI | macOS 14 API |
| 数据存储 | SQLite（系统内置 libsqlite3） | macOS 自带 |
| 依赖管理 | 无外部依赖 | 全部使用系统框架 |
| 目标系统 | macOS | 14.0+ |

## 架构模式：MVVM

```
View (SwiftUI) ←→ ViewModel (@Observable) ←→ Service/Model
```

- **View**：纯 UI 声明，不包含业务逻辑
- **ViewModel**：`@Observable` 类，持有数据状态，暴露操作接口
- **Service**：剪贴板监听、数据库操作、设置管理（单例模式）
- **Model**：纯数据结构体（`Codable`, `FetchableRecord` 等）

## 数据流

```
用户 ⌘+C 复制
    ↓
ClipboardMonitor (Timer 轮询 changeCount)
    ↓ 检测到变化
读取 NSPasteboard 内容
    ↓
去重检查（与上一条比对）
    ↓ 新内容
DataStore.insert(item)
    ↓ 写入成功
清理过期条目
    ↓
ClipboardViewModel 重新加载列表
    ↓
SwiftUI 自动刷新 UI
```

## 数据库设计

### 存储位置
- 数据库：`~/Library/Application Support/ClipboardHistory/clipboard.db`
- 图片：`~/Library/Application Support/ClipboardHistory/Images/<uuid>.png`

### 表结构

```sql
CREATE TABLE clipboard_items (
    id TEXT PRIMARY KEY,           -- UUID 字符串
    type TEXT NOT NULL,            -- "text" | "image"
    content TEXT,                  -- 文字内容（图片类型时为 NULL）
    image_path TEXT,               -- 图片文件路径（文字类型时为 NULL）
    created_at INTEGER NOT NULL,   -- Unix 时间戳（秒）
    is_pinned INTEGER DEFAULT 0    -- 0 = 未置顶, 1 = 置顶
);

CREATE INDEX idx_created_at ON clipboard_items(created_at DESC);
CREATE INDEX idx_is_pinned ON clipboard_items(is_pinned);
```

### 查询规范
- 列表查询：`ORDER BY is_pinned DESC, created_at DESC`
- 搜索查询：`WHERE type = 'text' AND content LIKE ? ORDER BY is_pinned DESC, created_at DESC`
- 清理查询：`DELETE WHERE is_pinned = 0 AND created_at < ?`

## 设置存储

使用 `UserDefaults` 存储，键名前缀 `com.clipboardhistory.`：

| 键名 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `storage_days` | Int | 3 | 存储期限（1/3/5） |
| `run_mode` | String | "both" | menuBar / dock / both |
| `launch_at_login` | Bool | true | 开机启动 |

## 权限配置

### Info.plist
```xml
<key>NSSystemAdministrationUsageDescription</key>
<string>ClipboardHistory 需要辅助功能权限来读取剪贴板内容。</string>
```

###  entitlements（如需）
- App Sandbox：关闭（需要读取全局剪贴板）
- Hardened Runtime：开启（用于公证分发）

## 错误处理策略

- 数据库操作失败：打印日志，静默降级，不崩溃
- 剪贴板读取失败：跳过本次轮询
- 图片保存失败：记录文字日志，该项不存入数据库
- 开机启动注册失败：静默处理，用户可手动设置

## 安全性

- 无网络请求代码
- 数据库文件权限 600（仅当前用户可读写）
- 图片文件权限 600
