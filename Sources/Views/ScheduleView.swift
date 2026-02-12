import SwiftUI
import SwiftData

struct ScheduleView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var courses: [Course]
    @Query private var configs: [SemesterConfig]
    @State private var currentWeek: Int = 1
    @State private var showImport = false
    @State private var showAddCourse = false
    @State private var showExportAlert = false
    @State private var exportAlertMessage = ""
    @State private var showShareSheet = false
    @State private var shareFileURL: URL?

    private var config: SemesterConfig? { configs.first }

    private var allSchedules: [CourseSchedule] {
        courses.flatMap { $0.schedules }
    }

    private var totalWeeks: Int {
        config?.totalWeeks ?? 20
    }

    // 计算当前是第几周
    private var calculatedCurrentWeek: Int {
        guard let config = config else { return 1 }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: config.startDate, to: Date())
        let days = components.day ?? 0
        let week = (days / 7) + 1
        return max(1, min(week, totalWeeks))
    }

    // 获取某周某天的日期
    private func dateForDay(_ dayOfWeek: Int, inWeek week: Int) -> Date {
        guard let config = config else { return Date() }
        let calendar = Calendar.current
        let daysOffset = (week - 1) * 7 + (dayOfWeek - 1)
        return calendar.date(byAdding: .day, value: daysOffset, to: config.startDate) ?? Date()
    }

    private let dayNames = ["一", "二", "三", "四", "五", "六", "日"]
    private let sectionCount = 12
    private let sectionHeight: CGFloat = 60

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                headerView
                weekDayHeader

                // 使用 TabView 实现左右滑动切换周次
                TabView(selection: $currentWeek) {
                    ForEach(1...totalWeeks, id: \.self) { week in
                        weekScheduleContent(week: week)
                            .tag(week)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        Button(action: { showAddCourse = true }) {
                            Image(systemName: "plus")
                        }
                        Button(action: { showImport = true }) {
                            Image(systemName: "square.and.arrow.down")
                        }
                        Menu {
                            Button {
                                exportToCalendar()
                            } label: {
                                Label("导入到日历", systemImage: "calendar.badge.plus")
                            }
                            Button {
                                exportToICalFile()
                            } label: {
                                Label("导出为iCal文件", systemImage: "doc.badge.arrow.up")
                            }
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            }
            .sheet(isPresented: $showImport) {
                ImportView()
            }
            .sheet(isPresented: $showAddCourse) {
                AddCourseView()
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = shareFileURL {
                    ShareSheet(items: [url])
                }
            }
            .alert("提示", isPresented: $showExportAlert) {
                Button("确定") { }
            } message: {
                Text(exportAlertMessage)
            }
            .onAppear {
                if config != nil {
                    currentWeek = calculatedCurrentWeek
                }
                if configs.isEmpty {
                    let defaultConfig = SemesterConfig(
                        semesterName: "2025-2026学年第二学期",
                        startDate: semesterStartDate(),
                        totalWeeks: 20,
                        sectionsPerDay: 12
                    )
                    modelContext.insert(defaultConfig)
                }
            }
        }
    }

    // MARK: - 某一周的课表内容
    private func weekScheduleContent(week: Int) -> some View {
        ScrollView {
            ZStack(alignment: .topLeading) {
                gridBackground
                courseBlocks(forWeek: week)
            }
        }
    }

    // MARK: - 顶部信息
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(dateString())
                    .font(.title2)
                    .fontWeight(.bold)
                HStack(spacing: 8) {
                    Text("第\(currentWeek)周")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if currentWeek != calculatedCurrentWeek {
                        Button {
                            withAnimation { currentWeek = calculatedCurrentWeek }
                        } label: {
                            Text("回到本周")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - 星期栏
    private var weekDayHeader: some View {
        HStack(spacing: 0) {
            // 左上角显示月份
            Text(monthString())
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(width: 40)

            ForEach(0..<7, id: \.self) { index in
                VStack(spacing: 2) {
                    Text(dayNames[index])
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(dayDateString(dayOfWeek: index + 1))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 4)
        .background(Color(.systemBackground))
    }

    // MARK: - 课表网格背景
    private var gridBackground: some View {
        VStack(spacing: 0) {
            ForEach(1...sectionCount, id: \.self) { section in
                HStack(spacing: 0) {
                    VStack(spacing: 0) {
                        Text("\(section)")
                            .font(.caption)
                            .fontWeight(.medium)
                        if let times = config?.sectionTimes,
                           let time = times.first(where: { $0.section == section }) {
                            Text(time.startTime)
                                .font(.system(size: 8))
                                .foregroundColor(.secondary)
                            Text(time.endTime)
                                .font(.system(size: 8))
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(width: 40, height: sectionHeight)

                    ForEach(0..<7, id: \.self) { _ in
                        Rectangle()
                            .fill(Color.clear)
                            .frame(height: sectionHeight)
                            .frame(maxWidth: .infinity)
                            .overlay(
                                Rectangle()
                                    .stroke(Color(.systemGray5), lineWidth: 0.5)
                            )
                    }
                }
            }
        }
    }

    // MARK: - 课程色块
    private func courseBlocks(forWeek week: Int) -> some View {
        GeometryReader { geometry in
            let dayWidth = (geometry.size.width - 40) / 7

            ForEach(schedulesForWeek(week), id: \.id) { schedule in
                if let course = schedule.course {
                    let x = 40 + dayWidth * CGFloat(schedule.dayOfWeek - 1)
                    let y = sectionHeight * CGFloat(schedule.startSection - 1)
                    let height = sectionHeight * CGFloat(schedule.endSection - schedule.startSection + 1)

                    CourseBlockView(
                        courseName: course.name,
                        classroom: schedule.classroom,
                        colorHex: course.colorHex
                    )
                    .frame(width: dayWidth - 2, height: height - 2)
                    .position(x: x + dayWidth / 2, y: y + height / 2)
                }
            }
        }
        .frame(height: sectionHeight * CGFloat(sectionCount))
    }

    // MARK: - 辅助方法

    private func schedulesForWeek(_ week: Int) -> [CourseSchedule] {
        allSchedules.filter { schedule in
            guard week >= schedule.startWeek && week <= schedule.endWeek else {
                return false
            }
            switch schedule.weekType {
            case 1: return week % 2 == 1
            case 2: return week % 2 == 0
            default: return true
            }
        }
    }

    private func dateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/M/d"
        return formatter.string(from: Date())
    }

    private func monthString() -> String {
        let date = dateForDay(1, inWeek: currentWeek)
        let formatter = DateFormatter()
        formatter.dateFormat = "M月"
        return formatter.string(from: date)
    }

    private func dayDateString(dayOfWeek: Int) -> String {
        let date = dateForDay(dayOfWeek, inWeek: currentWeek)
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }

    private func semesterStartDate() -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: "2026-02-16") ?? Date()
    }

    // MARK: - 导入到系统日历
    private func exportToCalendar() {
        guard let config = config else {
            exportAlertMessage = "请先设置学期信息"
            showExportAlert = true
            return
        }

        CalendarExporter.exportToCalendar(
            schedules: allSchedules,
            semesterStart: config.startDate
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let count):
                    exportAlertMessage = "成功导入 \(count) 个日历事件"
                case .failure(let error):
                    exportAlertMessage = "导入失败：\(error.localizedDescription)"
                }
                showExportAlert = true
            }
        }
    }

    // MARK: - 导出为iCal文件
    private func exportToICalFile() {
        guard let config = config else {
            exportAlertMessage = "请先设置学期信息"
            showExportAlert = true
            return
        }

        let icalString = CalendarExporter.generateICalString(
            schedules: allSchedules,
            config: config
        )

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("MySchedule.ics")
        do {
            try icalString.write(to: tempURL, atomically: true, encoding: .utf8)
            shareFileURL = tempURL
            showShareSheet = true
        } catch {
            exportAlertMessage = "导出失败：\(error.localizedDescription)"
            showExportAlert = true
        }
    }
}

// MARK: - 系统分享面板
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) { }
}

#Preview {
    ScheduleView()
        .modelContainer(for: [Course.self, CourseSchedule.self, SemesterConfig.self], inMemory: true)
}
