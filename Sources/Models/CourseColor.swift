import SwiftUI

/// 预定义课程颜色
enum CourseColor {
    static let palette: [String] = [
        "#4A90D9", // 蓝色
        "#E87C7C", // 红色
        "#7BC67E", // 绿色
        "#F5A623", // 橙色
        "#9B59B6", // 紫色
        "#1ABC9C", // 青色
        "#E67E22", // 深橙
        "#3498DB", // 亮蓝
        "#E74C3C", // 深红
        "#2ECC71", // 翠绿
        "#F39C12", // 金黄
        "#8E44AD", // 深紫
    ]

    static func color(at index: Int) -> String {
        palette[index % palette.count]
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)

        let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = Double(rgbValue & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}
