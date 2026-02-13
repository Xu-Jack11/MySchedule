import SwiftUI
import SwiftData

@main
struct MyScheduleApp: App {
    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(SharedModelContainer.container)
    }
}
