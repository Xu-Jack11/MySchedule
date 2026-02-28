import SwiftData
import Foundation

enum SharedModelContainer {
    /// 工程里的默认 App Group（未经过 AltStore 处理）
    static let defaultAppGroupID = "group.com.jack.myschedule"

    /// AltStore 重签时会写入 Info.plist 的动态 App Group 列表键
    private static let altAppGroupsInfoKey = "ALTAppGroups"

    /// 运行时从 Info.plist 读取到的 App Group 列表
    static var runtimeAppGroups: [String] {
        let value = Bundle.main.object(forInfoDictionaryKey: altAppGroupsInfoKey)
        if let groups = value as? [String], !groups.isEmpty {
            return groups
        }
        if let group = value as? String, !group.isEmpty {
            return [group]
        }
        return []
    }

    /// 当前应使用的 App Group ID
    /// 优先使用 AltStore 注入值；若无则回落到默认值。
    static var resolvedAppGroupID: String? {
        let groups = runtimeAppGroups
        if !groups.isEmpty {
            // 优先匹配默认前缀（AltStore 常见格式：group.xxx.yyy.<teamID>）
            if let preferred = groups.first(where: { $0 == defaultAppGroupID || $0.hasPrefix(defaultAppGroupID + ".") }) {
                return preferred
            }
            return groups.first
        }
        return defaultAppGroupID
    }

    static var appGroupURL: URL? {
        guard let groupID = resolvedAppGroupID else { return nil }
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID)
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

        func makeContainer(at url: URL) throws -> ModelContainer {
            let config = ModelConfiguration(schema: schema, url: url)
            return try ModelContainer(for: schema, configurations: [config])
        }

        // 1) 尝试 App Group 容器（用于主 App 与 Widget 共享）
        if let groupBaseURL = appGroupURL {
            let storeURL = groupBaseURL.appendingPathComponent("MySchedule.store")
            migrateIfNeeded(to: storeURL)
            do {
                return try makeContainer(at: storeURL)
            } catch {
                print("[SharedModelContainer] App Group 容器初始化失败，回退本地容器。error=\(error)")
            }
        } else {
            print("[SharedModelContainer] 运行时未获得可用 App Group，回退本地容器。")
        }

        // 2) 回退本地容器（保证扩展不因共享容器失败而崩溃）
        let localURL = URL.applicationSupportDirectory.appendingPathComponent("MySchedule.store")
        do {
            return try makeContainer(at: localURL)
        } catch {
            print("[SharedModelContainer] 本地容器初始化失败，回退内存容器。error=\(error)")
        }

        // 3) 最后回退内存容器（至少确保 Widget 能显示，不白屏）
        do {
            let memoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try ModelContainer(for: schema, configurations: [memoryConfig])
        } catch {
            fatalError("无法创建 ModelContainer: \(error)")
        }
    }()

    /// 将旧路径（ApplicationSupport）的 SwiftData 数据库迁移到 App Group 容器
    private static func migrateIfNeeded(to groupStoreURL: URL) {
        let fm = FileManager.default

        // 如果 App Group 里已有数据库，不需要迁移
        guard !fm.fileExists(atPath: groupStoreURL.path) else { return }

        // 确保目标目录存在
        let groupDir = groupStoreURL.deletingLastPathComponent()
        if !fm.fileExists(atPath: groupDir.path) {
            try? fm.createDirectory(at: groupDir, withIntermediateDirectories: true)
        }

        let oldURL = URL.applicationSupportDirectory.appendingPathComponent("MySchedule.store")
        guard fm.fileExists(atPath: oldURL.path) else { return }

        // SwiftData / SQLite 常见三个文件：.store, .store-shm, .store-wal
        let suffixes = ["", "-shm", "-wal"]
        for suffix in suffixes {
            let src = URL(fileURLWithPath: oldURL.path + suffix)
            let dst = URL(fileURLWithPath: groupStoreURL.path + suffix)
            if fm.fileExists(atPath: src.path), !fm.fileExists(atPath: dst.path) {
                try? fm.copyItem(at: src, to: dst)
            }
        }
    }
}
