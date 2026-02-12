import EventKit
import Foundation

struct CalendarExporter {

    // MARK: - 导入到系统日历
    static func exportToCalendar(
        schedules: [CourseSchedule],
        semesterStart: Date,
        completion: @escaping (Result<Int, Error>) -> Void
    ) {
        let store = EKEventStore()

        store.requestFullAccessToEvents { granted, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard granted else {
                completion(.failure(NSError(
                    domain: "CalendarExporter",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "未获得日历访问权限，请在设置中允许"]
                )))
                return
            }

            let calendar = Calendar.current
            let sectionTimes = SectionTime.defaultTimes()
            var count = 0

            for schedule in schedules {
                guard let course = schedule.course else { continue }

                let startTime = sectionTimes.first(where: { $0.section == schedule.startSection })
                let endTime = sectionTimes.first(where: { $0.section == schedule.endSection })

                guard let startTimeStr = startTime?.startTime,
                      let endTimeStr = endTime?.endTime else { continue }

                // 遍历每一周
                for week in schedule.startWeek...schedule.endWeek {
                    // 检查单双周
                    if schedule.weekType == 1 && week % 2 == 0 { continue }
                    if schedule.weekType == 2 && week % 2 == 1 { continue }

                    // 计算具体日期
                    let daysOffset = (week - 1) * 7 + (schedule.dayOfWeek - 1)
                    guard let dayDate = calendar.date(byAdding: .day, value: daysOffset, to: semesterStart) else { continue }

                    // 组合日期和时间
                    guard let startDate = combineDateAndTime(date: dayDate, time: startTimeStr),
                          let endDate = combineDateAndTime(date: dayDate, time: endTimeStr) else { continue }

                    let event = EKEvent(eventStore: store)
                    event.title = course.name
                    event.location = schedule.classroom
                    event.notes = "教师：\(course.teacher)"
                    event.startDate = startDate
                    event.endDate = endDate
                    event.calendar = store.defaultCalendarForNewEvents

                    do {
                        try store.save(event, span: .thisEvent)
                        count += 1
                    } catch {
                        // 跳过单个失败的事件
                    }
                }
            }

            completion(.success(count))
        }
    }

    // MARK: - 生成iCal字符串
    static func generateICalString(schedules: [CourseSchedule], config: SemesterConfig) -> String {
        let calendar = Calendar.current
        let sectionTimes = config.sectionTimes
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd'T'HHmmss"
        dateFormatter.timeZone = TimeZone(identifier: "Asia/Shanghai")

        var lines: [String] = []
        lines.append("BEGIN:VCALENDAR")
        lines.append("VERSION:2.0")
        lines.append("PRODID:-//MySchedule//CN")
        lines.append("CALSCALE:GREGORIAN")
        lines.append("X-WR-CALNAME:课程表")
        lines.append("X-WR-TIMEZONE:Asia/Shanghai")

        // 时区定义
        lines.append("BEGIN:VTIMEZONE")
        lines.append("TZID:Asia/Shanghai")
        lines.append("BEGIN:STANDARD")
        lines.append("DTSTART:19700101T000000")
        lines.append("TZOFFSETFROM:+0800")
        lines.append("TZOFFSETTO:+0800")
        lines.append("END:STANDARD")
        lines.append("END:VTIMEZONE")

        for schedule in schedules {
            guard let course = schedule.course else { continue }

            let startTime = sectionTimes.first(where: { $0.section == schedule.startSection })
            let endTime = sectionTimes.first(where: { $0.section == schedule.endSection })
            guard let startTimeStr = startTime?.startTime,
                  let endTimeStr = endTime?.endTime else { continue }

            for week in schedule.startWeek...schedule.endWeek {
                if schedule.weekType == 1 && week % 2 == 0 { continue }
                if schedule.weekType == 2 && week % 2 == 1 { continue }

                let daysOffset = (week - 1) * 7 + (schedule.dayOfWeek - 1)
                guard let dayDate = calendar.date(byAdding: .day, value: daysOffset, to: config.startDate),
                      let startDate = combineDateAndTime(date: dayDate, time: startTimeStr),
                      let endDate = combineDateAndTime(date: dayDate, time: endTimeStr) else { continue }

                let uid = UUID().uuidString

                lines.append("BEGIN:VEVENT")
                lines.append("UID:\(uid)")
                lines.append("DTSTART;TZID=Asia/Shanghai:\(dateFormatter.string(from: startDate))")
                lines.append("DTEND;TZID=Asia/Shanghai:\(dateFormatter.string(from: endDate))")
                lines.append("SUMMARY:\(escapeICalText(course.name))")
                lines.append("LOCATION:\(escapeICalText(schedule.classroom))")
                lines.append("DESCRIPTION:\(escapeICalText("教师：\(course.teacher)"))")
                lines.append("END:VEVENT")
            }
        }

        lines.append("END:VCALENDAR")
        return lines.joined(separator: "\r\n")
    }

    // MARK: - 辅助方法

    private static func combineDateAndTime(date: Date, time: String) -> Date? {
        let parts = time.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return nil }
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = parts[0]
        components.minute = parts[1]
        components.second = 0
        return calendar.date(from: components)
    }

    private static func escapeICalText(_ text: String) -> String {
        text.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: ";", with: "\\;")
            .replacingOccurrences(of: ",", with: "\\,")
            .replacingOccurrences(of: "\n", with: "\\n")
    }
}
