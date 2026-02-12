import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var courses: [Course]
    @Query private var configs: [SemesterConfig]
    @State private var showImport = false
    @State private var showClearAlert = false
    @State private var showDatePicker = false
    @State private var selectedDate = Date()

    private var config: SemesterConfig? { configs.first }

    var body: some View {
        NavigationStack {
            List {
                Section("学期设置") {
                    if let config = config {
                        HStack {
                            Text("学期")
                            Spacer()
                            Text(config.semesterName)
                                .foregroundColor(.secondary)
                        }

                        Button {
                            selectedDate = config.startDate
                            showDatePicker = true
                        } label: {
                            HStack {
                                Text("开学日期")
                                    .foregroundColor(.primary)
                                Spacer()
                                Text(formatDate(config.startDate))
                                    .foregroundColor(.secondary)
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        HStack {
                            Text("总周数")
                            Spacer()
                            Text("\(config.totalWeeks) 周")
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("未设置学期信息")
                            .foregroundColor(.secondary)
                    }
                }

                Section("课程管理") {
                    HStack {
                        Text("已导入课程")
                        Spacer()
                        Text("\(courses.count) 门")
                            .foregroundColor(.secondary)
                    }

                    Button("从教务系统导入") {
                        showImport = true
                    }

                    Button("清空所有课程", role: .destructive) {
                        showClearAlert = true
                    }
                }

                Section("关于") {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("我的")
            .sheet(isPresented: $showImport) {
                ImportView()
            }
            .sheet(isPresented: $showDatePicker) {
                NavigationStack {
                    DatePicker(
                        "选择开学日期",
                        selection: $selectedDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .padding()
                    .navigationTitle("开学日期")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("取消") {
                                showDatePicker = false
                            }
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("确定") {
                                if let config = config {
                                    config.startDate = selectedDate
                                    try? modelContext.save()
                                }
                                showDatePicker = false
                            }
                            .fontWeight(.semibold)
                        }
                    }
                }
                .presentationDetents([.medium])
            }
            .alert("确认清空", isPresented: $showClearAlert) {
                Button("取消", role: .cancel) { }
                Button("清空", role: .destructive) {
                    clearAllCourses()
                }
            } message: {
                Text("确定要删除所有已导入的课程吗？此操作不可撤销。")
            }
        }
    }

    private func clearAllCourses() {
        for course in courses {
            modelContext.delete(course)
        }
        try? modelContext.save()
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月d日"
        return formatter.string(from: date)
    }
}

#Preview {
    ProfileView()
        .modelContainer(for: [Course.self, CourseSchedule.self, SemesterConfig.self], inMemory: true)
}
