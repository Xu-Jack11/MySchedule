import SwiftUI
import SwiftData

@main
struct MyScheduleApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Course.self,
            CourseSchedule.self,
            SemesterConfig.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("无法创建 ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(sharedModelContainer)
    }
}
