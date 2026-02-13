import WidgetKit
import SwiftUI
import SwiftData

// MARK: - Timeline Entry
struct ScheduleEntry: TimelineEntry {
    let date: Date
    let todayCourses: [WidgetCourse]
    let semesterName: String
    let currentWeek: Int
}

struct WidgetCourse: Identifiable {
    let id: UUID
    let name: String
    let classroom: String
    let startSection: Int
    let endSection: Int
    let startTime: String
    let endTime: String
    let colorHex: String
    let dayOfWeek: Int
}

// MARK: - Timeline Provider
struct ScheduleProvider: TimelineProvider {
    func placeholder(in context: Context) -> ScheduleEntry {
        ScheduleEntry(
            date: Date(),
            todayCourses: [
                WidgetCourse(id: UUID(), name: "高级程序设计", classroom: "理4-220",
                            startSection: 1, endSection: 4, startTime: "08:00", endTime: "11:25",
                            colorHex: "#4A90D9", dayOfWeek: 1)
            ],
            semesterName: "2025-2026学年第二学期",
            currentWeek: 1
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (ScheduleEntry) -> Void) {
        let entry = fetchEntry(for: Date())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ScheduleEntry>) -> Void) {
        let now = Date()
        let entry = fetchEntry(for: now)

        // 每30分钟刷新一次，或在第二天0点刷新
        let calendar = Calendar.current
        let tomorrow = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: now)!)
        let halfHourLater = calendar.date(byAdding: .minute, value: 30, to: now)!
        let nextUpdate = min(tomorrow, halfHourLater)

        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func fetchEntry(for date: Date) -> ScheduleEntry {
        let container = SharedModelContainer.container
        let context = ModelContext(container)
        let calendar = Calendar.current

        // 获取激活学期
        let configDescriptor = FetchDescriptor<SemesterConfig>(
            predicate: #Predicate { $0.isActive }
        )
        guard let config = try? context.fetch(configDescriptor).first else {
            return ScheduleEntry(date: date, todayCourses: [], semesterName: "", currentWeek: 0)
        }

        // 计算当前周次
        let days = calendar.dateComponents([.day], from: config.startDate, to: date).day ?? 0
        let currentWeek = max(1, min((days / 7) + 1, config.totalWeeks))

        // 今天星期几 (1=周一...7=周日)
        let weekday = calendar.component(.weekday, from: date)
        let todayDayOfWeek = weekday == 1 ? 7 : weekday - 1

        // 获取所有课程
        let courseDescriptor = FetchDescriptor<Course>()
        let allCourses = (try? context.fetch(courseDescriptor)) ?? []

        // 筛选今日、本周的课程
        var todayCourses: [WidgetCourse] = []
        for course in allCourses {
            guard course.semester?.id == config.id else { continue }
            for schedule in course.schedules {
                guard schedule.dayOfWeek == todayDayOfWeek,
                      currentWeek >= schedule.startWeek,
                      currentWeek <= schedule.endWeek else { continue }

                // 单双周检查
                switch schedule.weekType {
                case 1: guard currentWeek % 2 == 1 else { continue }
                case 2: guard currentWeek % 2 == 0 else { continue }
                default: break
                }

                let startTime = config.sectionTimes.first(where: { $0.section == schedule.startSection })?.startTime ?? ""
                let endTime = config.sectionTimes.first(where: { $0.section == schedule.endSection })?.endTime ?? ""

                todayCourses.append(WidgetCourse(
                    id: schedule.id,
                    name: course.name,
                    classroom: schedule.classroom,
                    startSection: schedule.startSection,
                    endSection: schedule.endSection,
                    startTime: startTime,
                    endTime: endTime,
                    colorHex: course.colorHex,
                    dayOfWeek: schedule.dayOfWeek
                ))
            }
        }

        todayCourses.sort { $0.startSection < $1.startSection }

        return ScheduleEntry(
            date: date,
            todayCourses: todayCourses,
            semesterName: config.semesterName,
            currentWeek: currentWeek
        )
    }
}

// MARK: - Widget Definition
struct ScheduleWidget: Widget {
    let kind = "com.jack.myschedule.widget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ScheduleProvider()) { entry in
            ScheduleWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("今日课程")
        .description("查看今天的课程安排")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
