import Foundation
import SwiftData

/// 课程
@Model
final class Course {
    var id: UUID
    var name: String
    var teacher: String
    var colorHex: String
    var semester: SemesterConfig?

    @Relationship(deleteRule: .cascade, inverse: \CourseSchedule.course)
    var schedules: [CourseSchedule]

    init(name: String, teacher: String = "", colorHex: String = "#4A90D9", semester: SemesterConfig? = nil) {
        self.id = UUID()
        self.name = name
        self.teacher = teacher
        self.colorHex = colorHex
        self.semester = semester
        self.schedules = []
    }
}

/// 课程安排（某节课在什么时间、什么地点上）
@Model
final class CourseSchedule {
    var id: UUID
    var course: Course?
    var dayOfWeek: Int       // 1=周一 ... 7=周日
    var startSection: Int    // 开始节次（从1开始）
    var endSection: Int      // 结束节次
    var startWeek: Int       // 开始周次
    var endWeek: Int         // 结束周次
    var weekType: Int        // 0=每周, 1=单周, 2=双周
    var classroom: String

    init(
        course: Course? = nil,
        dayOfWeek: Int,
        startSection: Int,
        endSection: Int,
        startWeek: Int,
        endWeek: Int,
        weekType: Int = 0,
        classroom: String = ""
    ) {
        self.id = UUID()
        self.course = course
        self.dayOfWeek = dayOfWeek
        self.startSection = startSection
        self.endSection = endSection
        self.startWeek = startWeek
        self.endWeek = endWeek
        self.weekType = weekType
        self.classroom = classroom
    }
}

/// 学期配置
@Model
final class SemesterConfig {
    var id: UUID
    var semesterName: String       // 如 "2025-2026学年第二学期"
    var startDate: Date            // 学期第一周的周一日期
    var totalWeeks: Int            // 总周数
    var sectionsPerDay: Int        // 每天节数
    var sectionTimes: [SectionTime]  // 每节课的时间
    var isActive: Bool             // 是否为当前激活学期

    @Relationship(deleteRule: .cascade, inverse: \Course.semester)
    var courses: [Course]

    init(
        semesterName: String = "",
        startDate: Date = Date(),
        totalWeeks: Int = 20,
        sectionsPerDay: Int = 12,
        isActive: Bool = true
    ) {
        self.id = UUID()
        self.semesterName = semesterName
        self.startDate = startDate
        self.totalWeeks = totalWeeks
        self.sectionsPerDay = sectionsPerDay
        self.sectionTimes = SectionTime.defaultTimes()
        self.isActive = isActive
        self.courses = []
    }
}

/// 节次时间
struct SectionTime: Codable, Hashable {
    var section: Int
    var startTime: String  // "08:00"
    var endTime: String    // "08:45"

    static func defaultTimes() -> [SectionTime] {
        return [
            SectionTime(section: 1, startTime: "08:00", endTime: "08:45"),
            SectionTime(section: 2, startTime: "08:50", endTime: "09:35"),
            SectionTime(section: 3, startTime: "09:50", endTime: "10:35"),
            SectionTime(section: 4, startTime: "10:40", endTime: "11:25"),
            SectionTime(section: 5, startTime: "11:30", endTime: "12:15"),
            SectionTime(section: 6, startTime: "13:30", endTime: "14:15"),
            SectionTime(section: 7, startTime: "14:20", endTime: "15:05"),
            SectionTime(section: 8, startTime: "15:20", endTime: "16:05"),
            SectionTime(section: 9, startTime: "16:10", endTime: "16:55"),
            SectionTime(section: 10, startTime: "18:30", endTime: "19:15"),
            SectionTime(section: 11, startTime: "19:20", endTime: "20:05"),
            SectionTime(section: 12, startTime: "20:10", endTime: "20:55"),
        ]
    }
}
