import SwiftData
import Foundation

enum SharedModelContainer {
    static let appGroupID = "group.com.jack.myschedule"

    static var container: ModelContainer = {
        let schema = Schema([
            Course.self,
            CourseSchedule.self,
            SemesterConfig.self
        ])

        let url: URL
        if let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            url = groupURL.appendingPathComponent("MySchedule.store")
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
}
