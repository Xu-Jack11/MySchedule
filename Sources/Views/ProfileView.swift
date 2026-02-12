import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<SemesterConfig> { $0.isActive }) private var activeConfigs: [SemesterConfig]
    @Query private var allConfigs: [SemesterConfig]
    @State private var showImport = false
    @State private var showClearAlert = false
    @State private var showDatePicker = false
    @State private var selectedDate = Date()
    @State private var showSemesterManager = false
    @State private var showAddSemester = false

    private var config: SemesterConfig? { activeConfigs.first }

    private var currentCourses: [Course] {
        config?.courses ?? []
    }

    var body: some View {
        NavigationStack {
            List {
                // 学期切换
                Section {
                    Button {
                        showSemesterManager = true
                    } label: {
                        HStack {
                            Text("当前学期")
                                .foregroundColor(.primary)
                            Spacer()
                            Text(config?.semesterName ?? "未设置")
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("学期管理")
                }

                // 学期设置
                if let config = config {
                    Section("学期设置") {
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

                        Stepper("总周数：\(config.totalWeeks) 周", value: Binding(
                            get: { config.totalWeeks },
                            set: { newValue in
                                config.totalWeeks = newValue
                                try? modelContext.save()
                            }
                        ), in: 1...30)

                        NavigationLink {
                            SectionTimeSettingView()
                        } label: {
                            HStack {
                                Text("上课时间")
                                Spacer()
                                Text("\(config.sectionsPerDay) 节/天")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    Section("课程管理") {
                        HStack {
                            Text("已导入课程")
                            Spacer()
                            Text("\(currentCourses.count) 门")
                                .foregroundColor(.secondary)
                        }

                        Button("从教务系统导入") {
                            showImport = true
                        }

                        if !currentCourses.isEmpty {
                            Button("清空当前学期课程", role: .destructive) {
                                showClearAlert = true
                            }
                        }
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
                            Button("取消") { showDatePicker = false }
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
            .sheet(isPresented: $showSemesterManager) {
                SemesterManagerView()
            }
            .alert("确认清空", isPresented: $showClearAlert) {
                Button("取消", role: .cancel) { }
                Button("清空", role: .destructive) {
                    clearCurrentCourses()
                }
            } message: {
                Text("确定要删除当前学期的所有课程吗？此操作不可撤销。")
            }
        }
    }

    private func clearCurrentCourses() {
        guard let config = config else { return }
        for course in config.courses {
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

// MARK: - 学期管理页面
struct SemesterManagerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var configs: [SemesterConfig]
    @State private var showAddSemester = false
    @State private var showDeleteAlert = false
    @State private var configToDelete: SemesterConfig?

    var body: some View {
        NavigationStack {
            List {
                ForEach(configs.sorted(by: { $0.startDate > $1.startDate })) { config in
                    Button {
                        switchToSemester(config)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(config.semesterName)
                                    .foregroundColor(.primary)
                                    .fontWeight(config.isActive ? .semibold : .regular)
                                Text("\(config.courses.count) 门课程 · \(config.totalWeeks) 周")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if config.isActive {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if !config.isActive {
                            Button(role: .destructive) {
                                configToDelete = config
                                showDeleteAlert = true
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                }

                Button {
                    showAddSemester = true
                } label: {
                    Label("添加学期", systemImage: "plus.circle")
                }
            }
            .navigationTitle("学期管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
            .sheet(isPresented: $showAddSemester) {
                AddSemesterView()
            }
            .alert("确认删除", isPresented: $showDeleteAlert) {
                Button("取消", role: .cancel) { configToDelete = nil }
                Button("删除", role: .destructive) {
                    if let config = configToDelete {
                        modelContext.delete(config)
                        try? modelContext.save()
                    }
                    configToDelete = nil
                }
            } message: {
                if let config = configToDelete {
                    Text("确定要删除「\(config.semesterName)」及其所有课程数据吗？")
                }
            }
        }
    }

    private func switchToSemester(_ target: SemesterConfig) {
        for config in configs {
            config.isActive = (config.id == target.id)
        }
        try? modelContext.save()
    }
}

// MARK: - 添加学期页面
struct AddSemesterView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var semesterName = ""
    @State private var startDate = Date()
    @State private var totalWeeks = 20

    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("学期名称（如 2025-2026学年第一学期）", text: $semesterName)

                    DatePicker("开学日期", selection: $startDate, displayedComponents: .date)

                    Stepper("总周数：\(totalWeeks) 周", value: $totalWeeks, in: 1...30)
                }
            }
            .navigationTitle("添加学期")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("添加") {
                        let config = SemesterConfig(
                            semesterName: semesterName,
                            startDate: startDate,
                            totalWeeks: totalWeeks,
                            sectionsPerDay: 12,
                            isActive: false
                        )
                        modelContext.insert(config)
                        try? modelContext.save()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(semesterName.isEmpty)
                }
            }
        }
    }
}

#Preview {
    ProfileView()
        .modelContainer(for: [Course.self, CourseSchedule.self, SemesterConfig.self], inMemory: true)
}
