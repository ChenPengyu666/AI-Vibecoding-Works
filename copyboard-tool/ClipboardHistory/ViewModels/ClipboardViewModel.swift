import AppKit
import Foundation
import Observation

/// 剪贴板历史视图模型 — @Observable 自动驱动 SwiftUI 更新
@Observable
final class ClipboardViewModel {
    /// 全部记录（从数据库加载）
    private(set) var allItems: [ClipboardItem] = []
    /// 搜索文本
    var searchText = ""
    /// 点击复制后的高亮条目 ID
    var highlightedId: String?
    /// 图片预览的图片数据
    var previewImageData: Data?
    /// 文件预览的路径
    var previewFilePath: String?
    /// 显示的条目数
    var itemCount: Int { filteredItems.count }

    /// 根据搜索文本过滤后的条目
    var filteredItems: [ClipboardItem] {
        let sorted = allItems.sorted {
            if $0.isPinned != $1.isPinned { return $0.isPinned }
            return $0.createdAt > $1.createdAt
        }
        guard !searchText.isEmpty else { return sorted }
        return sorted.filter { item in
            // 搜索文本内容和文件名
            if item.type == .text, let content = item.content {
                return content.localizedCaseInsensitiveContains(searchText)
            }
            if let fileName = item.fileName {
                return fileName.localizedCaseInsensitiveContains(searchText)
            }
            return false
        }
    }

    // MARK: - 数据加载

    func refresh() {
        allItems = DataStore.shared.fetchAll()
    }

    // MARK: - 复制到剪贴板

    /// 点击卡片：将内容写回系统剪贴板
    func copyToClipboard(_ item: ClipboardItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        switch item.type {
        case .text:
            if let content = item.content {
                pasteboard.setString(content, forType: .string)
            }
        case .image:
            if let path = item.imagePath,
               let data = DataStore.shared.loadImage(at: path) {
                pasteboard.setData(data, forType: .png)
            }
        case .file:
            if let path = item.filePath {
                // 复制文件 URL 引用到剪贴板
                let fileURL = URL(fileURLWithPath: path)
                pasteboard.writeObjects([fileURL as NSURL])
            }
        }

        // 短暂高亮反馈
        highlightedId = item.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.highlightedId = nil
        }
    }

    // MARK: - 置顶

    func togglePin(_ item: ClipboardItem) {
        _ = DataStore.shared.togglePin(id: item.id)
        refresh()
    }

    // MARK: - 删除

    func delete(_ item: ClipboardItem) {
        _ = DataStore.shared.delete(id: item.id)
        refresh()
    }

    // MARK: - 批量删除

    /// 获取超过指定秒数的非置顶条目数量（用于确认对话框）
    func countItemsOlderThan(seconds: TimeInterval) -> Int {
        DataStore.shared.countOlderThan(seconds: seconds)
    }

    /// 获取全部条目数量（用于确认对话框）
    func countAllItems() -> Int {
        DataStore.shared.countAll()
    }

    /// 批量删除超过指定秒数的非置顶条目
    func bulkDeleteOlderThan(seconds: TimeInterval) -> Int {
        let count = DataStore.shared.deleteOlderThan(seconds: seconds)
        refresh()
        return count
    }

    /// 删除全部条目
    func bulkDeleteAll() -> Int {
        let count = DataStore.shared.deleteAll()
        refresh()
        return count
    }

    // MARK: - 图片/文件预览

    func previewImage(_ item: ClipboardItem) {
        guard item.type == .image, let path = item.imagePath else { return }
        previewImageData = DataStore.shared.loadImage(at: path)
    }

    func dismissPreview() {
        previewImageData = nil
        previewFilePath = nil
    }

    /// 在 Finder 中打开文件
    func openInFinder(_ item: ClipboardItem) {
        guard item.type == .file, let path = item.filePath else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }
}
