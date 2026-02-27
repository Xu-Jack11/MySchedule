import SwiftUI
import SwiftData
import WidgetKit

struct CourseDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var course: Course
    @State private var showDeleteAlert = false

    var body: some View {
        NavigationStack {
            List {
                // 课程基本信息
                Section("课程信息") {
                    EditableRow(label: "课程名称", text: $course.name)
                    EditableRow(label: "授课教师", text: $course.teacher)
                    ColorPickerRow(label: "颜色", colorHex: $course.colorHex)
                }

                // 各时间段安排
                ForEach(course.schedules.sorted(by: {
                    ($0.dayOfWeek, $0.startSection) < ($1.dayOfWeek, $1.startSection)
                })) { schedule in
                    Section {
                        ScheduleEditSection(schedule: schedule)
                    } header: {
                        HStack {
                            Text("时间安排")
                            Spacer()
                            Button(role: .destructive) {
                                modelContext.delete(schedule)
                                try? modelContext.save()
                            } label: {
                                Image(systemName: "trash")
                                    .font(.caption)
                            }
                        }
                    }
                }

                // 添加时间段
                Section {
                    Button {
                        addSchedule()
                    } label: {
                        Label("添加时间段", systemImage: "plus.circle")
                    }
                }

                // 删除课程
                Section {
                    Button("删除课程", role: .destructive) {
                        showDeleteAlert = true
                    }
                }
            }
            .navigationTitle("课程详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        try? modelContext.save()
                        WidgetCenter.shared.reloadAllTimelines()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .alert("确认删除", isPresented: $showDeleteAlert) {
                Button("取消", role: .cancel) { }
                Button("删除", role: .destructive) {
                    modelContext.delete(course)
                    try? modelContext.save()
                    WidgetCenter.shared.reloadAllTimelines()
                    dismiss()
                }
            } message: {
                Text("确定要删除「\(course.name)」及其所有时间安排吗？")
            }
        }
    }

    private func addSchedule() {
        let schedule = CourseSchedule(
            course: course,
            dayOfWeek: 1,
            startSection: 1,
            endSection: 2,
            startWeek: 1,
            endWeek: 16,
            weekType: 0,
            classroom: ""
        )
        modelContext.insert(schedule)
        try? modelContext.save()
    }
}

// MARK: - 时间安排编辑区
struct ScheduleEditSection: View {
    @Bindable var schedule: CourseSchedule

    private let dayNames = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]
    private let weekTypes = ["每周", "单周", "双周"]

    var body: some View {
        Picker("星期", selection: $schedule.dayOfWeek) {
            ForEach(1...7, id: \.self) { day in
                Text(dayNames[day - 1]).tag(day)
            }
        }

        Picker("开始节次", selection: $schedule.startSection) {
            ForEach(1...16, id: \.self) { s in
                Text("第\(s)节").tag(s)
            }
        }

        Picker("结束节次", selection: $schedule.endSection) {
            ForEach(schedule.startSection...16, id: \.self) { s in
                Text("第\(s)节").tag(s)
            }
        }

        Picker("开始周", selection: $schedule.startWeek) {
            ForEach(1...30, id: \.self) { w in
                Text("第\(w)周").tag(w)
            }
        }

        Picker("结束周", selection: $schedule.endWeek) {
            ForEach(schedule.startWeek...30, id: \.self) { w in
                Text("第\(w)周").tag(w)
            }
        }

        Picker("周类型", selection: $schedule.weekType) {
            ForEach(0..<3, id: \.self) { type in
                Text(weekTypes[type]).tag(type)
            }
        }

        EditableRow(label: "上课地点", text: $schedule.classroom)
    }
}

// MARK: - 可编辑行
struct EditableRow: View {
    let label: String
    @Binding var text: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            TextField(label, text: $text)
                .multilineTextAlignment(.trailing)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - 颜色选择
struct ColorPickerRow: View {
    let label: String
    @Binding var colorHex: String

    private let colors = CourseColor.palette

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                ForEach(colors, id: \.self) { hex in
                    Circle()
                        .fill(Color(hex: hex))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Circle()
                                .stroke(Color.primary, lineWidth: hex == colorHex ? 2.5 : 0)
                        )
                        .onTapGesture {
                            colorHex = hex
                        }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Course.self, CourseSchedule.self, SemesterConfig.self, configurations: config)
    let course = Course(name: "高级程序设计", teacher: "郭鸣", colorHex: "#4A90D9")
    container.mainContext.insert(course)
    let schedule = CourseSchedule(course: course, dayOfWeek: 5, startSection: 1, endSection: 4, startWeek: 1, endWeek: 16, classroom: "理4-220")
    container.mainContext.insert(schedule)
    return CourseDetailView(course: course)
        .modelContainer(container)
}
