import SwiftUI
import SwiftData
import WidgetKit

struct AddCourseView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<SemesterConfig> { $0.isActive }) private var activeConfigs: [SemesterConfig]

    @State private var courseName = ""
    @State private var teacher = ""
    @State private var classroom = ""
    @State private var dayOfWeek = 1
    @State private var startSection = 1
    @State private var endSection = 2
    @State private var startWeek = 1
    @State private var endWeek = 16
    @State private var weekType = 0  // 0=每周, 1=单周, 2=双周

    private var config: SemesterConfig? { activeConfigs.first }
    private let dayNames = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]
    private let weekTypes = ["每周", "单周", "双周"]

    private var maxSections: Int { config?.sectionsPerDay ?? 12 }
    private var maxWeeks: Int { config?.totalWeeks ?? 20 }

    var body: some View {
        NavigationStack {
            Form {
                Section("课程信息") {
                    TextField("课程名称", text: $courseName)
                    TextField("授课教师", text: $teacher)
                    TextField("上课地点", text: $classroom)
                }

                Section("上课时间") {
                    Picker("星期", selection: $dayOfWeek) {
                        ForEach(1...7, id: \.self) { day in
                            Text(dayNames[day - 1]).tag(day)
                        }
                    }

                    Picker("开始节次", selection: $startSection) {
                        ForEach(1...maxSections, id: \.self) { section in
                            Text("第\(section)节").tag(section)
                        }
                    }

                    Picker("结束节次", selection: $endSection) {
                        ForEach(startSection...maxSections, id: \.self) { section in
                            Text("第\(section)节").tag(section)
                        }
                    }
                }

                Section("周次") {
                    Picker("开始周", selection: $startWeek) {
                        ForEach(1...maxWeeks, id: \.self) { week in
                            Text("第\(week)周").tag(week)
                        }
                    }

                    Picker("结束周", selection: $endWeek) {
                        ForEach(startWeek...maxWeeks, id: \.self) { week in
                            Text("第\(week)周").tag(week)
                        }
                    }

                    Picker("周类型", selection: $weekType) {
                        ForEach(0..<3, id: \.self) { type in
                            Text(weekTypes[type]).tag(type)
                        }
                    }
                }
            }
            .navigationTitle("添加课程")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        saveCourse()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(courseName.isEmpty)
                }
            }
            .onChange(of: startSection) {
                if endSection < startSection {
                    endSection = startSection
                }
            }
            .onChange(of: startWeek) {
                if endWeek < startWeek {
                    endWeek = startWeek
                }
            }
        }
    }

    private func saveCourse() {
        let colorIndex = config?.courses.count ?? 0
        let course = Course(
            name: courseName,
            teacher: teacher,
            colorHex: CourseColor.color(at: colorIndex),
            semester: config
        )
        modelContext.insert(course)

        let schedule = CourseSchedule(
            course: course,
            dayOfWeek: dayOfWeek,
            startSection: startSection,
            endSection: endSection,
            startWeek: startWeek,
            endWeek: endWeek,
            weekType: weekType,
            classroom: classroom
        )
        modelContext.insert(schedule)
        try? modelContext.save()
        WidgetCenter.shared.reloadAllTimelines()
    }
}

#Preview {
    AddCourseView()
        .modelContainer(for: [Course.self, CourseSchedule.self, SemesterConfig.self], inMemory: true)
}
