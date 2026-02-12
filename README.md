# MySchedule 📅

个人课程表 iOS 应用，支持从正方教务系统导入课表数据。

## 功能

- **课表周视图**：左右滑动切换周次，按周显示课程，自动定位当前周
- **教务系统导入**：内置 WebView 登录正方教务系统（V-9.0），一键提取课表数据
- **手动添加课程**：支持自定义课程名称、教师、教室、节次、周次、单双周
- **课程详情编辑**：点击色块查看/修改课程信息，支持颜色自定义
- **多学期管理**：独立学期配置，课程数据按学期隔离，自由切换
- **上课时间设置**：自定义每日节数与各节次起止时间
- **日历导出**：导入到系统日历（EventKit）或导出为 iCal (.ics) 文件

## 技术栈

- SwiftUI + SwiftData
- iOS 17+
- WKWebView（教务系统登录与数据提取）
- EventKit（系统日历集成）
- XcodeGen（项目文件生成）

## 构建

### 前置条件

- Xcode 16.0+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

### 步骤

```bash
# 安装 XcodeGen（如未安装）
brew install xcodegen

# 生成 Xcode 项目
cd MySchedule
xcodegen generate

# 打开项目
open MySchedule.xcodeproj
```

在 Xcode 中选择目标设备后 Build & Run 即可。

## 项目结构

```
Sources/
├── App/
│   └── MyScheduleApp.swift          # 应用入口
├── Models/
│   ├── Models.swift                 # 数据模型（Course, CourseSchedule, SemesterConfig）
│   └── CourseColor.swift            # 课程颜色调色板
├── Views/
│   ├── MainTabView.swift            # 底部 Tab 导航
│   ├── ScheduleView.swift           # 课表周视图
│   ├── ImportView.swift             # 教务系统导入（WebView）
│   ├── ProfileView.swift            # 个人设置 & 学期管理
│   ├── AddCourseView.swift          # 手动添加课程
│   ├── CourseDetailView.swift       # 课程详情与编辑
│   ├── SectionTimeSettingView.swift # 上课时间设置
│   └── Components/
│       └── CourseBlockView.swift    # 课程色块组件
└── Services/
    ├── ScheduleParser.swift         # 课表 HTML/JSON 解析
    ├── TrustAllCerts.swift          # SSL 证书信任处理
    └── CalendarExporter.swift       # 日历导出服务
```

## 支持的教务系统

- 正方教务系统 V-9.0（已验证）
- 通过地址栏可输入其他教务系统 URL，但解析脚本针对正方 V-9.0 DOM 结构编写

## 许可证

MIT License
