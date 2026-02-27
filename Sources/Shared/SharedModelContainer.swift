import SwiftData
import Foundation

enum SharedModelContainer {
    static let appGroupID = "group.com.jack.myschedule"

    static var appGroupURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }

    static var isAppGroupEnabled: Bool {
        appGroupURL != nil
    }

    static var container: ModelContainer = {
        let schema = Schema([
            Course.self,
            CourseSchedule.self,
            SemesterConfig.self
        ])

        let url: URL
        if let groupURL = appGroupURL {
            url = groupURL.appendingPathComponent("MySchedule.store")
            // 迁移：如果 App Group 容器里还没有数据库，把旧数据复制过来
            migrateIfNeeded(to: url)
        } else {
            // Fallback: 没有 App Group 时使用默认路径
            url = URL.applicationSupportDirectory.appendingPathComponent("MySchedule.store")
        }

        let config = ModelConfiguration(schema: schema, url: url)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("无法创建 ModelContainer: \(error)")
        }
    }()

    /// 将旧路径（ApplicationSupport）的 SwiftData 数据库迁移到 App Group 容器
    private static func migrateIfNeeded(to groupURL: URL) {
        let fm = FileManager.default
        // 如果 App Group 里已有数据库，不需要迁移
        guard !fm.fileExists(atPath: groupURL.path) else { return }

        let oldURL = URL.applicationSupportDirectory.appendingPathComponent("MySchedule.store")
        guard fm.fileExists(atPath: oldURL.path) else { return }

        // SwiftData / SQLite 通常会有三个文件：.store, .store-shm, .store-wal
        let suffixes = ["", "-shm", "-wal"]
        for suffix in suffixes {
            let src = URL(fileURLWithPath: oldURL.path + suffix)
            let dst = URL(fileURLWithPath: groupURL.path + suffix)
            if fm.fileExists(atPath: src.path) {
                try? fm.copyItem(at: src, to: dst)
            }
        }
    }
}
