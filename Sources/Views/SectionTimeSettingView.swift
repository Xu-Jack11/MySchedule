import SwiftUI
import SwiftData

struct SectionTimeSettingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var configs: [SemesterConfig]
    @Query private var courses: [Course]

    @State private var sectionsPerDay: Int = 12
    @State private var sectionTimes: [SectionTime] = SectionTime.defaultTimes()
    @State private var editingSection: Int? = nil
    @State private var editingStart = Date()
    @State private var editingEnd = Date()
    @State private var showTimePicker = false

    private var config: SemesterConfig? { configs.first }

    private var allSchedules: [CourseSchedule] {
        courses.flatMap { $0.schedules }
    }

    var body: some View {
        List {
            // 每日节数
            Section {
                Stepper("每日节数：\(sectionsPerDay)", value: $sectionsPerDay, in: 4...16)
                    .onChange(of: sectionsPerDay) { _, newValue in
                        adjustSectionTimes(to: newValue)
                    }
            } header: {
                Text("节数设置")
            }

            // 各节时间段
            Section {
                ForEach(0..<sectionsPerDay, id: \.self) { index in
                    let time = sectionTimes[index]
                    Button {
                        editingSection = index
                        editingStart = timeStringToDate(time.startTime)
                        editingEnd = timeStringToDate(time.endTime)
                        showTimePicker = true
                    } label: {
                        HStack {
                            Text("第\(index + 1)节")
                                .foregroundColor(.primary)
                                .frame(width: 60, alignment: .leading)
                            Spacer()
                            Text("\(time.startTime) - \(time.endTime)")
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } header: {
                Text("时间段设置")
            } footer: {
                Text("点击可修改各节课的上课时间")
            }

            // 课表预览
            Section {
                schedulePreview
                    .frame(height: CGFloat(sectionsPerDay) * 44 + 30)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
            } header: {
                Text("课表预览")
            }
        }
        .navigationTitle("上课时间")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("保存") {
                    saveSettings()
                    dismiss()
                }
                .fontWeight(.semibold)
            }
        }
        .sheet(isPresented: $showTimePicker) {
            timePickerSheet
        }
        .onAppear {
            if let config = config {
                sectionsPerDay = config.sectionsPerDay
                sectionTimes = config.sectionTimes
                // 确保数组长度一致
                if sectionTimes.count < sectionsPerDay {
                    adjustSectionTimes(to: sectionsPerDay)
                }
            }
        }
    }

    // MARK: - 时间选择器
    private var timePickerSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let idx = editingSection {
                    Text("第\(idx + 1)节")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("上课时间")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        DatePicker("", selection: $editingStart, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .frame(height: 100)
                            .clipped()

                        Text("下课时间")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        DatePicker("", selection: $editingEnd, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .frame(height: 100)
                            .clipped()
                    }
                    .padding(.horizontal)
                }

                Spacer()
            }
            .padding(.top)
            .navigationTitle("设置时间")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { showTimePicker = false }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("确定") {
                        if let idx = editingSection {
                            sectionTimes[idx].startTime = dateToTimeString(editingStart)
                            sectionTimes[idx].endTime = dateToTimeString(editingEnd)
                        }
                        showTimePicker = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - 课表预览
    private var schedulePreview: some View {
        let dayNames = ["一", "二", "三", "四", "五", "六", "日"]
        let previewHeight: CGFloat = 44

        return VStack(spacing: 0) {
            // 星期栏
            HStack(spacing: 0) {
                Text("")
                    .frame(width: 50)
                ForEach(0..<7, id: \.self) { i in
                    Text(dayNames[i])
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 24)

            // 网格 + 课程
            ZStack(alignment: .topLeading) {
                // 网格
                VStack(spacing: 0) {
                    ForEach(0..<sectionsPerDay, id: \.self) { idx in
                        HStack(spacing: 0) {
                            VStack(spacing: 0) {
                                Text("\(idx + 1)")
                                    .font(.system(size: 9))
                                    .fontWeight(.medium)
                                if idx < sectionTimes.count {
                                    Text(sectionTimes[idx].startTime)
                                        .font(.system(size: 6))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .frame(width: 50, height: previewHeight)

                            ForEach(0..<7, id: \.self) { _ in
                                Rectangle()
                                    .fill(Color.clear)
                                    .frame(height: previewHeight)
                                    .frame(maxWidth: .infinity)
                                    .overlay(
                                        Rectangle()
                                            .stroke(Color(.systemGray5), lineWidth: 0.5)
                                    )
                            }
                        }
                    }
                }

                // 课程色块预览
                GeometryReader { geometry in
                    let dayWidth = (geometry.size.width - 50) / 7

                    // 使用第1周的课程来预览
                    ForEach(schedulesForPreview(), id: \.id) { schedule in
                        if let course = schedule.course,
                           schedule.startSection <= sectionsPerDay {
                            let endSection = min(schedule.endSection, sectionsPerDay)
                            let x = 50 + dayWidth * CGFloat(schedule.dayOfWeek - 1)
                            let y = previewHeight * CGFloat(schedule.startSection - 1)
                            let height = previewHeight * CGFloat(endSection - schedule.startSection + 1)

                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(hex: course.colorHex).opacity(0.7))
                                .frame(width: dayWidth - 2, height: height - 2)
                                .overlay(
                                    Text(course.name)
                                        .font(.system(size: 7))
                                        .foregroundColor(.white)
                                        .lineLimit(2)
                                        .padding(2)
                                )
                                .position(x: x + dayWidth / 2, y: y + height / 2)
                        }
                    }
                }
                .frame(height: previewHeight * CGFloat(sectionsPerDay))
            }
        }
    }

    // MARK: - 辅助方法

    private func schedulesForPreview() -> [CourseSchedule] {
        allSchedules.filter { schedule in
            schedule.startWeek <= 1 && schedule.endWeek >= 1
        }
    }

    private func adjustSectionTimes(to count: Int) {
        while sectionTimes.count < count {
            let lastTime = sectionTimes.last
            let newStart = addMinutes(to: lastTime?.endTime ?? "08:00", minutes: 10)
            let newEnd = addMinutes(to: newStart, minutes: 45)
            sectionTimes.append(SectionTime(
                section: sectionTimes.count + 1,
                startTime: newStart,
                endTime: newEnd
            ))
        }
        if sectionTimes.count > count {
            sectionTimes = Array(sectionTimes.prefix(count))
        }
    }

    private func saveSettings() {
        guard let config = config else { return }
        config.sectionsPerDay = sectionsPerDay
        config.sectionTimes = Array(sectionTimes.prefix(sectionsPerDay))
        // 更新section编号
        for i in 0..<config.sectionTimes.count {
            config.sectionTimes[i].section = i + 1
        }
        try? modelContext.save()
    }

    private func timeStringToDate(_ time: String) -> Date {
        let parts = time.split(separator: ":").compactMap { Int($0) }
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = parts.count > 0 ? parts[0] : 8
        components.minute = parts.count > 1 ? parts[1] : 0
        return calendar.date(from: components) ?? Date()
    }

    private func dateToTimeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func addMinutes(to time: String, minutes: Int) -> String {
        let parts = time.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return time }
        var totalMinutes = parts[0] * 60 + parts[1] + minutes
        totalMinutes = min(totalMinutes, 23 * 60 + 59)
        return String(format: "%02d:%02d", totalMinutes / 60, totalMinutes % 60)
    }
}

#Preview {
    NavigationStack {
        SectionTimeSettingView()
    }
    .modelContainer(for: [Course.self, CourseSchedule.self, SemesterConfig.self], inMemory: true)
}
