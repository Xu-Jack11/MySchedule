import SwiftUI

struct CourseBlockView: View {
    let courseName: String
    let classroom: String
    let teacher: String
    let colorHex: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(hex: colorHex).opacity(0.85))

            VStack(spacing: 1) {
                Text(courseName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.7)

                if !teacher.isEmpty {
                    Text(teacher)
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .multilineTextAlignment(.center)
                }

                if !classroom.isEmpty {
                    Text(classroom)
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 4)
        }
    }
}

#Preview {
    HStack {
        CourseBlockView(
            courseName: "高级程序设计",
            classroom: "理4-220",
            teacher: "郭鸣",
            colorHex: "#4A90D9"
        )
        .frame(width: 50, height: 240)

        CourseBlockView(
            courseName: "大数据计算技术",
            classroom: "教五405",
            teacher: "张老师",
            colorHex: "#E87C7C"
        )
        .frame(width: 50, height: 120)
    }
}
