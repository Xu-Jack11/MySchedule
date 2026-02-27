import Foundation

extension Date {
    /// 返回包含该日期的那周的周一（基于 Calendar.current）
    var mondayOfWeek: Date {
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // 周一为一周开始
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        return calendar.date(from: components) ?? self
    }

    /// 是否是周一
    var isMonday: Bool {
        Calendar.current.component(.weekday, from: self) == 2
    }

    /// 中文星期名，如 "周三"
    var chineseWeekdayName: String {
        let names = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
        let index = Calendar.current.component(.weekday, from: self) - 1
        return names[index]
    }
}
