import Foundation
import AppKit
import SQLite3

/// 数据存储层 — 封装 SQLite3 操作
final class DataStore {
    static let shared = DataStore()

    private var db: OpaquePointer?

    // MARK: - 初始化

    private init() {
        openDatabase()
        createTable()
        migrateSchema()
        createImagesDirectory()
    }

    deinit {
        if let db = db {
            sqlite3_close(db)
        }
    }

    // MARK: - 路径

    private var supportDir: URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        return appSupport.appendingPathComponent("ClipboardHistory")
    }

    var dbPath: String {
        supportDir.appendingPathComponent("clipboard.db").path
    }

    var imagesDir: URL {
        supportDir.appendingPathComponent("Images")
    }

    // MARK: - 数据库打开与建表

    private func openDatabase() {
        // 确保目录存在
        try? FileManager.default.createDirectory(
            at: supportDir,
            withIntermediateDirectories: true
        )

        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            print("[DataStore] 无法打开数据库: \(errorMessage)")
            db = nil
        } else {
            // 启用 WAL 模式提升并发性能
            execute("PRAGMA journal_mode=WAL")
            execute("PRAGMA foreign_keys=ON")
        }
    }

    private func createTable() {
        let sql = """
            CREATE TABLE IF NOT EXISTS clipboard_items (
                id TEXT PRIMARY KEY,
                type TEXT NOT NULL,
                content TEXT,
                image_path TEXT,
                file_path TEXT,
                file_name TEXT,
                created_at INTEGER NOT NULL,
                is_pinned INTEGER DEFAULT 0
            );
            CREATE INDEX IF NOT EXISTS idx_created_at
                ON clipboard_items(created_at DESC);
            CREATE INDEX IF NOT EXISTS idx_is_pinned
                ON clipboard_items(is_pinned);
        """
        execute(sql)
    }

    /// 为旧版本数据库添加新列（兼容迁移）
    private func migrateSchema() {
        // 尝试添加 file_path 列（如果已存在则忽略错误）
        execute("ALTER TABLE clipboard_items ADD COLUMN file_path TEXT")
        execute("ALTER TABLE clipboard_items ADD COLUMN file_name TEXT")
    }

    private func createImagesDirectory() {
        try? FileManager.default.createDirectory(
            at: imagesDir,
            withIntermediateDirectories: true
        )
    }

    // MARK: - 原始执行

    @discardableResult
    private func execute(_ sql: String) -> Bool {
        guard let db = db else { return false }
        var errMsg: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, sql, nil, nil, &errMsg) != SQLITE_OK {
            if let msg = errMsg {
                let msgStr = String(cString: msg)
                // 忽略 "duplicate column name" 迁移错误
                if !msgStr.contains("duplicate column name") {
                    print("[DataStore] SQL 执行失败: \(msgStr)")
                }
                sqlite3_free(errMsg)
            }
            return false
        }
        return true
    }

    private var errorMessage: String {
        guard let db = db else { return "数据库未打开" }
        return String(cString: sqlite3_errmsg(db))
    }

    private func notifyDataChanged() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .clipboardDataChanged, object: nil)
        }
    }

    // MARK: - 增删改查

    /// 插入一条剪贴板记录
    func insert(_ item: ClipboardItem) -> Bool {
        guard let db = db else { return false }
        let sql = """
            INSERT INTO clipboard_items (id, type, content, image_path, file_path, file_name, created_at, is_pinned)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?);
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            print("[DataStore] 插入预编译失败: \(errorMessage)")
            return false
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, item.id, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_bind_text(stmt, 2, item.type.rawValue, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        if let content = item.content {
            sqlite3_bind_text(stmt, 3, content, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        } else {
            sqlite3_bind_null(stmt, 3)
        }
        if let imagePath = item.imagePath {
            sqlite3_bind_text(stmt, 4, imagePath, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        } else {
            sqlite3_bind_null(stmt, 4)
        }
        if let filePath = item.filePath {
            sqlite3_bind_text(stmt, 5, filePath, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        } else {
            sqlite3_bind_null(stmt, 5)
        }
        if let fileName = item.fileName {
            sqlite3_bind_text(stmt, 6, fileName, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        } else {
            sqlite3_bind_null(stmt, 6)
        }
        sqlite3_bind_int64(stmt, 7, Int64(item.createdAt))
        sqlite3_bind_int(stmt, 8, item.isPinned ? 1 : 0)

        if sqlite3_step(stmt) != SQLITE_DONE {
            print("[DataStore] 插入失败: \(errorMessage)")
            return false
        }
        notifyDataChanged()
        return true
    }

    /// 获取所有记录，按置顶优先 + 时间倒序
    func fetchAll() -> [ClipboardItem] {
        let sql = """
            SELECT id, type, content, image_path, file_path, file_name, created_at, is_pinned
            FROM clipboard_items
            ORDER BY is_pinned DESC, created_at DESC;
        """
        return query(sql)
    }

    /// 搜索文字记录（按内容模糊匹配）
    func search(_ queryText: String) -> [ClipboardItem] {
        let sql = """
            SELECT id, type, content, image_path, file_path, file_name, created_at, is_pinned
            FROM clipboard_items
            WHERE type = 'text' AND content LIKE ?
            ORDER BY is_pinned DESC, created_at DESC;
        """
        return query(sql, bind: { stmt in
            let pattern = "%\(queryText)%"
            sqlite3_bind_text(stmt, 1, pattern, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        })
    }

    /// 获取最近一条记录（用于去重）
    func fetchLatest() -> ClipboardItem? {
        let sql = """
            SELECT id, type, content, image_path, file_path, file_name, created_at, is_pinned
            FROM clipboard_items
            ORDER BY created_at DESC
            LIMIT 1;
        """
        return query(sql).first
    }

    /// 删除一条记录
    func delete(id: String) -> Bool {
        // 如果是图片类型，先删除本地图片文件
        if let item = fetchById(id), item.type == .image, let imagePath = item.imagePath {
            try? FileManager.default.removeItem(atPath: imagePath)
        }

        guard let db = db else { return false }
        let sql = "DELETE FROM clipboard_items WHERE id = ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, id, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        let success = sqlite3_step(stmt) == SQLITE_DONE
        if success { notifyDataChanged() }
        return success
    }

    /// 切换置顶状态
    func togglePin(id: String) -> Bool {
        guard let db = db, let item = fetchById(id) else { return false }
        let sql = "UPDATE clipboard_items SET is_pinned = ? WHERE id = ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_int(stmt, 1, item.isPinned ? 0 : 1)
        sqlite3_bind_text(stmt, 2, id, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        let success = sqlite3_step(stmt) == SQLITE_DONE
        if success { notifyDataChanged() }
        return success
    }

    /// 根据 ID 查找单条记录
    func fetchById(_ id: String) -> ClipboardItem? {
        let sql = """
            SELECT id, type, content, image_path, file_path, file_name, created_at, is_pinned
            FROM clipboard_items
            WHERE id = ?;
        """
        return query(sql, bind: { stmt in
            sqlite3_bind_text(stmt, 1, id, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        }).first
    }

    // MARK: - 批量删除

    /// 统计超过指定秒数的非置顶条目数量
    func countOlderThan(seconds: TimeInterval) -> Int {
        let cutoff = Int(Date().timeIntervalSince1970 - seconds)
        guard let db = db else { return 0 }
        let sql = "SELECT COUNT(*) FROM clipboard_items WHERE is_pinned = 0 AND created_at < ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return 0 }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_int64(stmt, 1, Int64(cutoff))
        if sqlite3_step(stmt) == SQLITE_ROW {
            return Int(sqlite3_column_int(stmt, 0))
        }
        return 0
    }

    /// 统计全部条目数量
    func countAll() -> Int {
        guard let db = db else { return 0 }
        let sql = "SELECT COUNT(*) FROM clipboard_items;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return 0 }
        defer { sqlite3_finalize(stmt) }

        if sqlite3_step(stmt) == SQLITE_ROW {
            return Int(sqlite3_column_int(stmt, 0))
        }
        return 0
    }

    /// 删除超过指定秒数的非置顶条目，返回删除数量
    func deleteOlderThan(seconds: TimeInterval) -> Int {
        let cutoff = Int(Date().timeIntervalSince1970 - seconds)
        guard let db = db else { return 0 }

        // 先查出图片记录以便删除本地图片文件
        let findImages = """
            SELECT image_path FROM clipboard_items
            WHERE is_pinned = 0 AND created_at < ? AND type = 'image' AND image_path IS NOT NULL;
        """
        var imageStmt: OpaquePointer?
        if sqlite3_prepare_v2(db, findImages, -1, &imageStmt, nil) == SQLITE_OK {
            sqlite3_bind_int64(imageStmt, 1, Int64(cutoff))
            while sqlite3_step(imageStmt) == SQLITE_ROW {
                if let path = sqlite3_column_text(imageStmt, 0) {
                    try? FileManager.default.removeItem(atPath: String(cString: path))
                }
            }
            sqlite3_finalize(imageStmt)
        }

        // 删除记录
        let sql = "DELETE FROM clipboard_items WHERE is_pinned = 0 AND created_at < ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return 0 }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_int64(stmt, 1, Int64(cutoff))
        if sqlite3_step(stmt) == SQLITE_DONE {
            let deleted = Int(sqlite3_changes(db))
            if deleted > 0 {
                print("[DataStore] 批量删除了 \(deleted) 条记录（超过 \(Int(seconds)) 秒）")
                notifyDataChanged()
            }
            return deleted
        }
        return 0
    }

    /// 删除全部条目（包括置顶），返回删除数量
    func deleteAll() -> Int {
        guard let db = db else { return 0 }

        // 先删除所有本地图片文件
        let findImages = "SELECT image_path FROM clipboard_items WHERE type = 'image' AND image_path IS NOT NULL;"
        var imageStmt: OpaquePointer?
        if sqlite3_prepare_v2(db, findImages, -1, &imageStmt, nil) == SQLITE_OK {
            while sqlite3_step(imageStmt) == SQLITE_ROW {
                if let path = sqlite3_column_text(imageStmt, 0) {
                    try? FileManager.default.removeItem(atPath: String(cString: path))
                }
            }
            sqlite3_finalize(imageStmt)
        }

        // 删除所有记录
        let sql = "DELETE FROM clipboard_items;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return 0 }
        defer { sqlite3_finalize(stmt) }

        if sqlite3_step(stmt) == SQLITE_DONE {
            let deleted = Int(sqlite3_changes(db))
            if deleted > 0 {
                print("[DataStore] 已删除全部 \(deleted) 条记录")
                notifyDataChanged()
            }
            return deleted
        }
        return 0
    }

    // MARK: - 清理

    /// 删除过期的非置顶条目
    func cleanupExpired(olderThan seconds: TimeInterval) -> Int {
        let cutoff = Int(Date().timeIntervalSince1970 - seconds)
        guard let db = db else { return 0 }

        // 先查出过期的图片记录以便删除本地图片文件
        let findImages = """
            SELECT image_path FROM clipboard_items
            WHERE is_pinned = 0 AND created_at < ? AND type = 'image' AND image_path IS NOT NULL;
        """
        var imageStmt: OpaquePointer?
        if sqlite3_prepare_v2(db, findImages, -1, &imageStmt, nil) == SQLITE_OK {
            sqlite3_bind_int64(imageStmt, 1, Int64(cutoff))
            while sqlite3_step(imageStmt) == SQLITE_ROW {
                if let path = sqlite3_column_text(imageStmt, 0) {
                    try? FileManager.default.removeItem(atPath: String(cString: path))
                }
            }
            sqlite3_finalize(imageStmt)
        }

        // 删除过期记录
        let sql = "DELETE FROM clipboard_items WHERE is_pinned = 0 AND created_at < ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return 0 }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_int64(stmt, 1, Int64(cutoff))
        if sqlite3_step(stmt) == SQLITE_DONE {
            let deleted = Int(sqlite3_changes(db))
            if deleted > 0 {
                print("[DataStore] 清理了 \(deleted) 条过期记录")
                notifyDataChanged()
            }
            return deleted
        }
        return 0
    }

    // MARK: - 图片文件操作

    /// 将图片数据保存到文件，返回文件路径
    func saveImage(data: Data) -> String? {
        let filename = UUID().uuidString + ".png"
        let fileURL = imagesDir.appendingPathComponent(filename)
        do {
            // 尝试将 TIFF/其他格式转为 PNG
            if let image = NSImage(data: data),
               let tiffData = image.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiffData),
               let pngData = bitmap.representation(using: NSBitmapImageRep.FileType.png, properties: [:]) {
                try pngData.write(to: fileURL)
            } else {
                try data.write(to: fileURL)
            }
            return fileURL.path
        } catch {
            print("[DataStore] 图片保存失败: \(error)")
            return nil
        }
    }

    /// 获取图片数据
    func loadImage(at path: String) -> Data? {
        return try? Data(contentsOf: URL(fileURLWithPath: path))
    }

    // MARK: - 通用查询辅助

    private func query(
        _ sql: String,
        bind: ((OpaquePointer) -> Void)? = nil
    ) -> [ClipboardItem] {
        guard let db = db else { return [] }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK,
              let stmt = stmt else {
            print("[DataStore] 查询预编译失败: \(errorMessage)")
            return []
        }
        defer { sqlite3_finalize(stmt) }

        bind?(stmt)

        var items: [ClipboardItem] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let item = rowToItem(stmt) {
                items.append(item)
            }
        }
        return items
    }

    /// 将当前行转为 ClipboardItem
    private func rowToItem(_ stmt: OpaquePointer) -> ClipboardItem? {
        guard let id = sqlite3_column_text(stmt, 0),
              let typeRaw = sqlite3_column_text(stmt, 1) else { return nil }

        let type = ClipboardItem.ItemType(rawValue: String(cString: typeRaw)) ?? .text
        let content = sqlite3_column_text(stmt, 2).map { String(cString: $0) }
        let imagePath = sqlite3_column_text(stmt, 3).map { String(cString: $0) }
        let filePath = sqlite3_column_text(stmt, 4).map { String(cString: $0) }
        let fileName = sqlite3_column_text(stmt, 5).map { String(cString: $0) }
        let createdAt = Int(sqlite3_column_int64(stmt, 6))
        let isPinned = sqlite3_column_int(stmt, 7) != 0

        return ClipboardItem(
            id: String(cString: id),
            type: type,
            content: content,
            imagePath: imagePath,
            filePath: filePath,
            fileName: fileName,
            createdAt: createdAt,
            isPinned: isPinned
        )
    }
}
