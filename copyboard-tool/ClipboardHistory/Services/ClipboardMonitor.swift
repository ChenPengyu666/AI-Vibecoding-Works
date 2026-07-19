import AppKit
import Foundation

/// 剪贴板监听服务 — 每 0.5 秒轮询 NSPasteboard，自动捕获文字、图片和文件
final class ClipboardMonitor {
    static let shared = ClipboardMonitor()

    private var timer: Timer?
    private var lastChangeCount: Int = -1
    private var lastTextContent: String?
    private var lastImageData: Data?
    private var lastFilePath: String?
    private let pasteboard = NSPasteboard.general
    private let pollingInterval: TimeInterval = 0.5

    /// 图片文件扩展名
    private let imageExtensions = Set([
        "png", "jpg", "jpeg", "gif", "bmp", "tiff", "tif", "heic", "heif", "webp", "svg", "ico", "icns", "raw", "cr2", "nef"
    ])

    /// 常见的可预览文件扩展名
    private let knownExtensions = Set([
        // 图片
        "png", "jpg", "jpeg", "gif", "bmp", "tiff", "tif", "heic", "heif", "webp", "svg", "ico", "icns",
        // 文档
        "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt", "rtf", "csv", "pages", "numbers", "key",
        // 视频
        "mp4", "mov", "avi", "mkv", "m4v", "wmv", "flv", "webm",
        // 音频
        "mp3", "wav", "aac", "m4a", "flac", "ogg",
        // 压缩
        "zip", "rar", "7z", "tar", "gz", "dmg", "iso",
        // 代码
        "swift", "py", "js", "ts", "html", "css", "json", "xml", "md", "sh", "rb", "go", "rs", "c", "cpp", "h", "java", "kt"
    ])

    private init() {}

    // MARK: - 启动与停止

    /// 开始监听剪贴板变化
    func start() {
        guard timer == nil else { return }

        lastChangeCount = pasteboard.changeCount

        timer = Timer.scheduledTimer(
            withTimeInterval: pollingInterval,
            repeats: true
        ) { [weak self] _ in
            self?.checkPasteboard()
        }

        // 确保 Timer 在主线程 RunLoop 上运行
        if let timer = timer {
            RunLoop.main.add(timer, forMode: .common)
        }

        print("[ClipboardMonitor] 开始监听剪贴板（间隔 \(pollingInterval)秒）")
    }

    /// 停止监听
    func stop() {
        timer?.invalidate()
        timer = nil
        print("[ClipboardMonitor] 已停止监听")
    }

    // MARK: - 核心逻辑

    private func checkPasteboard() {
        let currentChangeCount = pasteboard.changeCount

        // changeCount 未变化，跳过
        guard currentChangeCount != lastChangeCount else { return }
        lastChangeCount = currentChangeCount

        // 1. 优先检查文件 URL（从 Finder 复制文件时，读实际文件）
        if let fileURL = readFileURLFromPasteboard() {
            let ext = fileURL.pathExtension.lowercased()
            let isImage = imageExtensions.contains(ext)

            if isImage {
                // 图片文件：读取数据并保存副本
                if let imageData = try? Data(contentsOf: fileURL) {
                    handleImage(imageData, fileName: fileURL.lastPathComponent)
                    return
                }
                // 图片读取失败，回退为普通文件
                handleFile(filePath: fileURL.path, fileName: fileURL.lastPathComponent)
                return
            } else {
                // 非图片文件：记录文件引用
                handleFile(filePath: fileURL.path, fileName: fileURL.lastPathComponent)
                return
            }
        }

        // 2. 检查直接图片数据（截图、从浏览器/Preview 复制图片）
        if let imageData = readImageData() {
            handleImage(imageData, fileName: nil)
            return
        }

        // 3. 检查文字
        if let text = pasteboard.string(forType: .string), !text.isEmpty {
            // 如果文字是纯文件名且已有文件 URL 被处理，跳过
            if isPlainFilename(text) && fileURLWasJustProcessed() {
                return
            }
            handleText(text)
            return
        }
    }

    /// 检测是否刚处理了文件 URL（避免重复捕获文件名文字）
    private func fileURLWasJustProcessed() -> Bool {
        return lastFilePath != nil
    }

    /// 如果文字只是单纯的文件名（带常见扩展名），可能是复制文件产生的残留文字
    private func isPlainFilename(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        for ext in knownExtensions {
            if trimmed.hasSuffix(".\(ext)") { return true }
        }
        return false
    }

    // MARK: - 文字处理

    private func handleText(_ text: String) {
        // 去重：与上一条文字内容相同则跳过
        if text == lastTextContent {
            return
        }
        lastTextContent = text
        lastImageData = nil
        lastFilePath = nil

        let item = ClipboardItem.textItem(
            id: UUID().uuidString,
            content: text,
            createdAt: Int(Date().timeIntervalSince1970)
        )

        if DataStore.shared.insert(item) {
            print("[ClipboardMonitor] 已记录文字: \(text.prefix(50))...")
            cleanupIfNeeded()
        }
    }

    // MARK: - 图片处理

    private func handleImage(_ data: Data, fileName: String?) {
        // 去重：比较图片数据大小
        if let last = lastImageData, data.count == last.count {
            return
        }
        lastImageData = data
        lastTextContent = nil
        lastFilePath = nil

        guard let imagePath = DataStore.shared.saveImage(data: data) else {
            print("[ClipboardMonitor] 图片保存失败")
            return
        }

        let item = ClipboardItem.imageItem(
            id: UUID().uuidString,
            imagePath: imagePath,
            fileName: fileName,
            createdAt: Int(Date().timeIntervalSince1970)
        )

        if DataStore.shared.insert(item) {
            let nameInfo = fileName.map { "（\($0)）" } ?? ""
            print("[ClipboardMonitor] 已记录图片\(nameInfo): \(data.count) bytes")
            cleanupIfNeeded()
        }
    }

    // MARK: - 文件处理

    private func handleFile(filePath: String, fileName: String?) {
        // 去重：相同文件路径跳过
        if let last = lastFilePath, last == filePath {
            return
        }
        lastFilePath = filePath
        lastTextContent = nil
        lastImageData = nil

        let item = ClipboardItem.fileItem(
            id: UUID().uuidString,
            filePath: filePath,
            fileName: fileName,
            createdAt: Int(Date().timeIntervalSince1970)
        )

        if DataStore.shared.insert(item) {
            let nameInfo = fileName ?? filePath
            print("[ClipboardMonitor] 已记录文件: \(nameInfo)")
            cleanupIfNeeded()
        }
    }

    // MARK: - 图片读取

    /// 从剪贴板读取图片数据，优先 PNG 格式
    private func readImageData() -> Data? {
        // 尝试读取 PNG
        if let data = pasteboard.data(forType: .png) {
            return data
        }
        // 尝试读取 TIFF
        if let data = pasteboard.data(forType: .tiff) {
            return data
        }
        return nil
    }

    /// 从剪贴板的文件 URL 读取文件引用
    /// 返回找到的第一个文件 URL
    private func readFileURLFromPasteboard() -> URL? {
        // 遍历 pasteboardItems 读取 fileURL 类型
        guard let items = pasteboard.pasteboardItems else { return nil }

        for item in items {
            if let fileURLData = item.data(forType: .fileURL),
               let fileURLString = String(data: fileURLData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               let fileURL = URL(string: fileURLString) {
                // 检查文件是否仍然存在
                guard FileManager.default.fileExists(atPath: fileURL.path) else { continue }
                print("[ClipboardMonitor] 检测到文件 URL: \(fileURL.lastPathComponent)")
                return fileURL
            }
        }

        return nil
    }

    // MARK: - 过期清理

    private var lastCleanupTime: TimeInterval = 0
    private let cleanupInterval: TimeInterval = 60 // 每 60 秒最多清理一次

    private func cleanupIfNeeded() {
        let now = Date().timeIntervalSince1970
        guard now - lastCleanupTime >= cleanupInterval else { return }
        lastCleanupTime = now

        let seconds = SettingsManager.shared.storageSeconds
        DataStore.shared.cleanupExpired(olderThan: seconds)
    }
}
