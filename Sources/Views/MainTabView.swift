import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            ScheduleView()
                .tabItem {
                    Image(systemName: "books.vertical")
                    Text("课程")
                }
                .tag(0)

            ProfileView()
                .tabItem {
                    Image(systemName: "person")
                    Text("我的")
                }
                .tag(1)
        }
    }
}

#Preview {
    MainTabView()
}
