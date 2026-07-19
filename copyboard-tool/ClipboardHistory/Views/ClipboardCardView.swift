import SwiftUI

/// 单条剪贴板记录卡片（文字 / 图片 / 文件三种样式）
struct ClipboardCardView: View {
    let item: ClipboardItem
    let isHighlighted: Bool
    let onCopy: () -> Void
    let onTogglePin: () -> Void
    let onDelete: () -> Void
    let onPreviewImage: () -> Void
    let onOpenInFinder: (() -> Void)?

    init(
        item: ClipboardItem,
        isHighlighted: Bool,
        onCopy: @escaping () -> Void,
        onTogglePin: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        onPreviewImage: @escaping () -> Void,
        onOpenInFinder: (() -> Void)? = nil
    ) {
        self.item = item
        self.isHighlighted = isHighlighted
        self.onCopy = onCopy
        self.onTogglePin = onTogglePin
        self.onDelete = onDelete
        self.onPreviewImage = onPreviewImage
        self.onOpenInFinder = onOpenInFinder
    }

    var body: some View {
        HStack(spacing: 0) {
            // 置顶左边框标记
            if item.isPinned {
                Rectangle()
                    .fill(Color.accent)
                    .frame(width: 3)
            }

            // 卡片主体
            HStack(alignment: .top, spacing: 10) {
                // 图标 / 缩略图区
                if item.type == .image {
                    thumbnailView
                } else if item.type == .file {
                    fileIconView
                }

                // 内容区
                VStack(alignment: .leading, spacing: 4) {
                    // 主标题
                    if item.type == .text {
                        Text(item.content ?? "")
                            .font(.system(size: 13))
                            .lineLimit(3)
                            .foregroundColor(Color(hex: "333333"))
                    } else {
                        // 图片或文件类型：显示文件名
                        Text(item.fileName ?? (item.type == .image ? "图片" : "文件"))
                            .font(.system(size: 13, weight: .medium))
                            .lineLimit(1)
                            .foregroundColor(Color(hex: "333333"))

                        // 附加信息
                        if item.type == .image {
                            if let path = item.imagePath {
                                Text(formatFileSize(path))
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        } else if item.type == .file {
                            HStack(spacing: 4) {
                                if let path = item.filePath {
                                    Text(formatFileSize(path))
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                                if let path = item.filePath {
                                    Text("·")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                    Text(URL(fileURLWithPath: path).pathExtension.uppercased())
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.accent)
                                }
                            }
                        }
                    }

                    // 时间 + 操作按钮
                    HStack {
                        Text(timeAgo(from: item.createdAt))
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "666666"))

                        Spacer()

                        // 文件类型：在 Finder 中显示
                        if item.type == .file, let onOpen = onOpenInFinder {
                            Button(action: onOpen) {
                                Image(systemName: "folder")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(hex: "999999"))
                            }
                            .buttonStyle(.plain)
                            .help("在 Finder 中显示")
                        }

                        // 置顶按钮
                        Button(action: onTogglePin) {
                            Image(systemName: item.isPinned ? "pin.fill" : "pin")
                                .font(.system(size: 12))
                                .foregroundColor(item.isPinned ? .accent : Color(hex: "999999"))
                        }
                        .buttonStyle(.plain)
                        .help(item.isPinned ? "取消置顶" : "置顶")

                        // 删除按钮
                        Button(action: onDelete) {
                            Image(systemName: "trash")
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "999999"))
                        }
                        .buttonStyle(.plain)
                        .help("删除")
                    }
                }

                Spacer()
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHighlighted ? Color.accent.opacity(0.2) : cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isHighlighted ? Color.accent : Color(hex: "E0E0E0"), lineWidth: 1)
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            onCopy()
        }
    }

    // MARK: - 图片缩略图

    private var thumbnailView: some View {
        Group {
            if let path = item.imagePath,
               let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
               let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .onTapGesture {
                        onPreviewImage()
                    }
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(white: 0.9))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.secondary)
                    )
            }
        }
    }

    // MARK: - 文件图标

    private var fileIconView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(fileTypeColor.opacity(0.12))
                .frame(width: 40, height: 40)

            Image(systemName: fileTypeIcon)
                .font(.system(size: 18))
                .foregroundColor(fileTypeColor)
        }
    }

    /// 根据文件扩展名返回对应的 SF Symbol 图标
    private var fileTypeIcon: String {
        guard let path = item.filePath else { return "doc" }
        let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
        switch ext {
        // 文档
        case "pdf": return "doc.richtext"
        case "doc", "docx", "pages": return "doc.text"
        case "xls", "xlsx", "csv", "numbers": return "tablecells"
        case "ppt", "pptx", "key": return "chart.bar.doc.horizontal"
        case "txt", "rtf", "md": return "doc.plaintext"
        // 视频
        case "mp4", "mov", "avi", "mkv", "m4v", "wmv", "flv", "webm": return "play.rectangle"
        // 音频
        case "mp3", "wav", "aac", "m4a", "flac", "ogg": return "waveform"
        // 压缩
        case "zip", "rar", "7z", "tar", "gz", "dmg", "iso": return "doc.zipper"
        // 代码
        case "swift", "py", "js", "ts", "html", "css", "json", "xml", "sh", "rb", "go", "rs", "c", "cpp", "h", "java", "kt": return "chevron.left.forwardslash.chevron.right"
        // 图片（作为文件引用记录时）
        case "png", "jpg", "jpeg", "gif", "bmp", "tiff", "tif", "heic", "webp", "svg": return "photo"
        default: return "doc"
        }
    }

    /// 根据文件扩展名返回图标颜色
    private var fileTypeColor: Color {
        guard let path = item.filePath else { return .accent }
        let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
        switch ext {
        case "pdf": return Color(hex: "E88B8B")
        case "doc", "docx", "pages", "txt", "rtf", "md": return Color(hex: "5B9BD5")
        case "xls", "xlsx", "csv", "numbers": return Color(hex: "70AD47")
        case "ppt", "pptx", "key": return Color(hex: "ED7D31")
        case "mp4", "mov", "avi", "mkv", "m4v", "webm": return Color(hex: "9B59B6")
        case "mp3", "wav", "aac", "m4a", "flac", "ogg": return Color(hex: "E67E22")
        case "zip", "rar", "7z", "tar", "gz", "dmg", "iso": return Color(hex: "95A5A6")
        case "swift", "py", "js", "ts", "html", "css", "json", "xml", "sh", "rb", "go", "rs", "c", "cpp", "h", "java", "kt": return Color(hex: "7EC8E3")
        default: return .accent
        }
    }

    // MARK: - 辅助

    private var cardBackground: Color {
        item.isPinned
            ? Color(hex: "F5F7FA")
            : .white
    }

    private func timeAgo(from timestamp: Int) -> String {
        let seconds = Int(Date().timeIntervalSince1970) - timestamp
        switch seconds {
        case ..<60: return "刚刚"
        case ..<3600: return "\(seconds / 60) 分钟前"
        case ..<86400: return "\(seconds / 3600) 小时前"
        default: return "\(seconds / 86400) 天前"
        }
    }

    private func formatFileSize(_ path: String) -> String {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let size = attrs[.size] as? Int else { return "" }
        if size < 1024 { return "\(size) B" }
        if size < 1024 * 1024 { return "\(size / 1024) KB" }
        return String(format: "%.1f MB", Double(size) / (1024 * 1024))
    }
}

// MARK: - Hex 颜色扩展

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: .alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
