import SwiftUI
import WidgetKit

// MARK: - 入口视图（根据尺寸分发）
struct ScheduleWidgetEntryView: View {
    var entry: ScheduleEntry

    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - 小组件：下一节课
struct SmallWidgetView: View {
    let entry: ScheduleEntry

    private var nextCourse: WidgetCourse? {
        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        let currentTime = String(format: "%02d:%02d", hour, minute)

        // 找到还没结束的第一节课
        return entry.todayCourses.first { $0.endTime > currentTime }
            ?? entry.todayCourses.last
    }

    var body: some View {
        if let course = nextCourse {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("第\(entry.currentWeek)周")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(dateString()) \(weekdayString())")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(hex: course.colorHex).opacity(0.2))
                    .overlay(
                        VStack(alignment: .leading, spacing: 3) {
                            Text(course.name)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .lineLimit(2)
                            if !course.teacher.isEmpty {
                                Text(course.teacher)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            if !course.classroom.isEmpty {
                                Text("@\(course.classroom)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Text("\(course.startTime)-\(course.endTime)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(8),
                        alignment: .topLeading
                    )
            }
        } else {
            VStack(spacing: 8) {
                Image(systemName: "moon.zzz")
                    .font(.title2)
                    .foregroundColor(.secondary)
                Text("今日无课")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("第\(entry.currentWeek)周")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.6))
                Text("\(dateString()) \(weekdayString())")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.6))
            }
        }
    }

    private func dateString() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "MM/dd"
        return formatter.string(from: entry.date)
    }

    private func weekdayString() -> String {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: entry.date)
        let names = ["日", "一", "二", "三", "四", "五", "六"]
        return "周\(names[weekday - 1])"
    }
}

// MARK: - 中组件：今日课程列表
struct MediumWidgetView: View {
    let entry: ScheduleEntry

    var body: some View {
        if entry.todayCourses.isEmpty {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    headerRow
                    Spacer()
                    HStack {
                        Image(systemName: "moon.zzz")
                            .foregroundColor(.secondary)
                        Text("今日无课，好好休息")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                Spacer()
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                headerRow
                ForEach(entry.todayCourses.prefix(3)) { course in
                    courseRow(course)
                }
                if entry.todayCourses.count > 3 {
                    Text("还有 \(entry.todayCourses.count - 3) 节课...")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var headerRow: some View {
        HStack {
            Text("今日课程")
                .font(.subheadline)
                .fontWeight(.semibold)
            Spacer()
            Text("\(dateString()) \(weekdayString()) · 第\(entry.currentWeek)周")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    private func dateString() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "MM/dd"
        return formatter.string(from: entry.date)
    }

    private func weekdayString() -> String {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: entry.date)
        let names = ["日", "一", "二", "三", "四", "五", "六"]
        return "周\(names[weekday - 1])"
    }

    private func courseRow(_ course: WidgetCourse) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(hex: course.colorHex))
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 1) {
                Text(course.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    if !course.teacher.isEmpty {
                        Text(course.teacher)
                            .lineLimit(1)
                    }
                    if !course.classroom.isEmpty {
                        Text("@\(course.classroom)")
                            .lineLimit(1)
                    }
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }

            Spacer()

            Text("\(course.startTime)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(height: 28)
    }
}

// MARK: - 大组件：今日完整课表
struct LargeWidgetView: View {
    let entry: ScheduleEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 顶栏
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("今日课程")
                        .font(.headline)
                    Text("\(dateString()) · 第\(entry.currentWeek)周 · \(weekdayString())")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text("\(entry.todayCourses.count) 节")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Divider()

            if entry.todayCourses.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "moon.zzz")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("今日无课")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                Spacer()
            } else {
                ForEach(entry.todayCourses) { course in
                    largeCourseRow(course)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func largeCourseRow(_ course: WidgetCourse) -> some View {
        HStack(spacing: 10) {
            // 时间列
            VStack(spacing: 2) {
                Text(course.startTime)
                    .font(.caption2)
                    .fontWeight(.medium)
                Text(course.endTime)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(width: 40)

            // 课程卡片
            HStack {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(hex: course.colorHex))
                    .frame(width: 4)

                VStack(alignment: .leading, spacing: 2) {
                    Text(course.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        if !course.teacher.isEmpty {
                            Text(course.teacher)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        if !course.classroom.isEmpty {
                            Text("@ \(course.classroom)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()

                Text("第\(course.startSection)-\(course.endSection)节")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(Color(hex: course.colorHex).opacity(0.1))
            .cornerRadius(8)
        }
    }

    private func dateString() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "MM/dd"
        return formatter.string(from: entry.date)
    }

    private func weekdayString() -> String {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: entry.date)
        let names = ["日", "一", "二", "三", "四", "五", "六"]
        return "周\(names[weekday - 1])"
    }
}

// MARK: - Preview
#Preview(as: .systemSmall) {
    ScheduleWidget()
} timeline: {
    ScheduleEntry(date: Date(), todayCourses: [
        WidgetCourse(id: UUID(), name: "高级程序设计", classroom: "理4-220", teacher: "郭鸣",
                    startSection: 1, endSection: 4, startTime: "08:00", endTime: "11:25",
                    colorHex: "#4A90D9", dayOfWeek: 5)
    ], semesterName: "2025-2026学年第二学期", currentWeek: 1)
}

#Preview(as: .systemMedium) {
    ScheduleWidget()
} timeline: {
    ScheduleEntry(date: Date(), todayCourses: [
        WidgetCourse(id: UUID(), name: "高级程序设计", classroom: "理4-220", teacher: "郭鸣",
                    startSection: 1, endSection: 4, startTime: "08:00", endTime: "11:25",
                    colorHex: "#4A90D9", dayOfWeek: 5),
        WidgetCourse(id: UUID(), name: "计算机视觉", classroom: "理4-534", teacher: "李老师",
                    startSection: 6, endSection: 9, startTime: "13:30", endTime: "16:55",
                    colorHex: "#7BC67E", dayOfWeek: 5)
    ], semesterName: "2025-2026学年第二学期", currentWeek: 1)
}
