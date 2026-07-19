import Foundation

/// 剪贴板条目模型
struct ClipboardItem: Identifiable, Codable, Equatable {
    /// 唯一标识
    let id: String
    /// 类型：text / image / file
    let type: ItemType
    /// 文字内容（仅 text 类型使用）
    let content: String?
    /// 图片文件路径（仅 image 类型使用，已保存到本地 Images 目录的副本）
    let imagePath: String?
    /// 原始文件路径（仅 file 类型使用，记录原始文件的磁盘路径）
    let filePath: String?
    /// 原始文件名（image 和 file 类型使用）
    let fileName: String?
    /// 创建时间（Unix 时间戳，秒）
    let createdAt: Int
    /// 是否置顶
    var isPinned: Bool

    enum ItemType: String, Codable {
        case text
        case image
        case file
    }

    /// 创建文字条目
    static func textItem(id: String, content: String, createdAt: Int) -> ClipboardItem {
        ClipboardItem(
            id: id,
            type: .text,
            content: content,
            imagePath: nil,
            filePath: nil,
            fileName: nil,
            createdAt: createdAt,
            isPinned: false
        )
    }

    /// 创建图片条目
    static func imageItem(id: String, imagePath: String, fileName: String?, createdAt: Int) -> ClipboardItem {
        ClipboardItem(
            id: id,
            type: .image,
            content: nil,
            imagePath: imagePath,
            filePath: nil,
            fileName: fileName,
            createdAt: createdAt,
            isPinned: false
        )
    }

    /// 创建文件条目（非图片文件：Word / 视频 / PDF 等）
    static func fileItem(id: String, filePath: String, fileName: String?, createdAt: Int) -> ClipboardItem {
        ClipboardItem(
            id: id,
            type: .file,
            content: nil,
            imagePath: nil,
            filePath: filePath,
            fileName: fileName,
            createdAt: createdAt,
            isPinned: false
        )
    }
}
