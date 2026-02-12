import SwiftUI
import SwiftData
import WebKit

struct ImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var configs: [SemesterConfig]
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isImporting = false
    @State private var webView: WKWebView?
    @State private var urlText = "https://ijw.hzcu.edu.cn"
    @State private var currentURLString = "https://ijw.hzcu.edu.cn"

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 地址栏
                HStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    TextField("输入教务系统地址", text: $urlText)
                        .font(.caption)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .onSubmit {
                            navigateToURL()
                        }

                    Button {
                        navigateToURL()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .padding(.horizontal)
                .padding(.top, 8)

                Text("登录教务系统并切换到课程表页面，然后点击「确认导入」")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
                    .padding(.bottom, 4)

                ImportWebView(
                    url: URL(string: urlText) ?? URL(string: "https://ijw.hzcu.edu.cn")!,
                    webView: $webView,
                    onURLChange: { newURL in
                        currentURLString = newURL
                        urlText = newURL
                    }
                )

                // 底部确认按钮
                Button(action: {
                    performImport()
                }) {
                    if isImporting {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    } else {
                        Text("确认导入")
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                }
                .background(isImporting ? Color.gray : Color.blue)
                .cornerRadius(12)
                .disabled(isImporting)
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
            .navigationTitle("导入课表")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
            }
            .alert("提示", isPresented: $showAlert) {
                Button("确定") { }
            } message: {
                Text(alertMessage)
            }
        }
    }

    private func navigateToURL() {
        var input = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !input.hasPrefix("http://") && !input.hasPrefix("https://") {
            input = "https://" + input
        }
        guard let url = URL(string: input) else { return }
        urlText = input
        webView?.load(URLRequest(url: url))
    }

    private func performImport() {
        guard let webView = webView else {
            alertMessage = "WebView尚未加载"
            showAlert = true
            return
        }

        isImporting = true

        // 优先使用JavaScript从DOM直接提取课程数据
        webView.evaluateJavaScript(ScheduleParser.extractionJS) { result, error in
            DispatchQueue.main.async {
                if let jsonString = result as? String {
                    // 调试：保存JS提取结果到文件
                    let debugDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                    try? jsonString.write(to: debugDir.appendingPathComponent("debug_js.json"), atomically: true, encoding: .utf8)

                    let (courses, totalSections) = ScheduleParser.parseFromJS(jsonString: jsonString)
                    if !courses.isEmpty {
                        importCourses(courses, tableSections: totalSections)
                        isImporting = false
                        alertMessage = "成功导入 \(courses.count) 条课程安排"
                        showAlert = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            dismiss()
                        }
                        return
                    }
                }

                // JS提取失败，获取HTML并保存调试文件，然后尝试解析
                webView.evaluateJavaScript("document.documentElement.outerHTML") { htmlResult, htmlError in
                    DispatchQueue.main.async {
                        if let html = htmlResult as? String {
                            // 调试：保存HTML到文件
                            let debugDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                            try? html.write(to: debugDir.appendingPathComponent("debug_page.html"), atomically: true, encoding: .utf8)

                            if let htmlData = html.data(using: .utf8) {
                                let courses = ScheduleParser.parse(data: htmlData)
                                if !courses.isEmpty {
                                    importCourses(courses)
                                    isImporting = false
                                    alertMessage = "成功导入 \(courses.count) 条课程安排"
                                    showAlert = true
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                        dismiss()
                                    }
                                    return
                                }
                            }
                        }

                        // HTML也失败，尝试API
                        fetchScheduleViaAPI(webView: webView)
                    }
                }
            }
        }
    }

    private func fetchScheduleViaAPI(webView: WKWebView) {
        WKWebsiteDataStore.default().httpCookieStore.getAllCookies { cookies in
            let cookieHeader = cookies
                .filter { $0.domain.contains("hzcu.edu.cn") }
                .map { "\($0.name)=\($0.value)" }
                .joined(separator: "; ")

            guard let url = URL(string: "https://ijw.hzcu.edu.cn/jwglxt/kbcx/xskbcx_cxXsgrkb.html?gnmkdm=N253508") else {
                DispatchQueue.main.async {
                    isImporting = false
                    alertMessage = "未能从当前页面解析到课表数据，请确认已切换到课程表页面"
                    showAlert = true
                }
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

            let currentYear = Calendar.current.component(.year, from: Date())
            let currentMonth = Calendar.current.component(.month, from: Date())
            let xnm = currentMonth >= 9 ? "\(currentYear)" : "\(currentYear - 1)"
            let xqm = currentMonth >= 2 && currentMonth <= 7 ? "12" : "3"
            request.httpBody = "xnm=\(xnm)&xqm=\(xqm)".data(using: .utf8)

            let delegate = TrustAllCertsDelegate()
            let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)

            session.dataTask(with: request) { data, response, error in
                DispatchQueue.main.async {
                    isImporting = false

                    if let error = error {
                        alertMessage = "API请求失败：\(error.localizedDescription)"
                        showAlert = true
                        return
                    }

                    guard let data = data else {
                        alertMessage = "未能从当前页面解析到课表数据，请确认已切换到课程表页面"
                        showAlert = true
                        return
                    }

                    let courses = ScheduleParser.parse(data: data)
                    if courses.isEmpty {
                        alertMessage = "未能解析到课程数据。请确认：\n1. 已登录教务系统\n2. 已切换到课程表页面"
                        showAlert = true
                    } else {
                        importCourses(courses)
                        alertMessage = "成功导入 \(courses.count) 条课程安排"
                        showAlert = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            dismiss()
                        }
                    }
                }
            }.resume()
        }
    }

    private func importCourses(_ data: [ParsedCourse], tableSections: Int = 0) {
        var colorIndex = 0
        var courseMap: [String: Course] = [:]

        for item in data {
            let course: Course
            if let existing = courseMap[item.name] {
                course = existing
            } else {
                course = Course(
                    name: item.name,
                    teacher: item.teacher,
                    colorHex: CourseColor.color(at: colorIndex)
                )
                colorIndex += 1
                courseMap[item.name] = course
                modelContext.insert(course)
            }

            let schedule = CourseSchedule(
                course: course,
                dayOfWeek: item.dayOfWeek,
                startSection: item.startSection,
                endSection: item.endSection,
                startWeek: item.startWeek,
                endWeek: item.endWeek,
                weekType: item.weekType,
                classroom: item.classroom
            )
            modelContext.insert(schedule)
        }

        // 根据课表表格总节次数更新每日节数
        if tableSections > 0, let config = configs.first {
            config.sectionsPerDay = tableSections
            // 确保sectionTimes数组覆盖所有节次
            while config.sectionTimes.count < tableSections {
                let lastTime = config.sectionTimes.last
                let newStart = addMinutes(to: lastTime?.endTime ?? "08:00", minutes: 10)
                let newEnd = addMinutes(to: newStart, minutes: 45)
                config.sectionTimes.append(SectionTime(
                    section: config.sectionTimes.count + 1,
                    startTime: newStart,
                    endTime: newEnd
                ))
            }
            // 如果表格节次少于当前配置，也同步缩减
            if tableSections < config.sectionTimes.count {
                config.sectionTimes = Array(config.sectionTimes.prefix(tableSections))
            }
        }

        try? modelContext.save()
    }

    private func addMinutes(to time: String, minutes: Int) -> String {
        let parts = time.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return time }
        var totalMinutes = parts[0] * 60 + parts[1] + minutes
        totalMinutes = min(totalMinutes, 23 * 60 + 59)
        return String(format: "%02d:%02d", totalMinutes / 60, totalMinutes % 60)
    }
}

/// 解析后的课程数据
struct ParsedCourse {
    let name: String
    let teacher: String
    let classroom: String
    let dayOfWeek: Int
    let startSection: Int
    let endSection: Int
    let startWeek: Int
    let endWeek: Int
    let weekType: Int  // 0=每周, 1=单周, 2=双周
}

/// 纯WebView封装，不做任何自动检测
struct ImportWebView: UIViewRepresentable {
    let url: URL
    @Binding var webView: WKWebView?
    var onURLChange: ((String) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        // 允许JavaScript打开新窗口时在当前WebView中处理
        config.preferences.javaScriptCanOpenWindowsAutomatically = true

        let wv = WKWebView(frame: .zero, configuration: config)
        wv.navigationDelegate = context.coordinator
        wv.uiDelegate = context.coordinator
        wv.allowsBackForwardNavigationGestures = true
        wv.load(URLRequest(url: url))

        DispatchQueue.main.async {
            self.webView = wv
        }

        return wv
    }

    func updateUIView(_ uiView: WKWebView, context: Context) { }

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        let parent: ImportWebView

        init(_ parent: ImportWebView) {
            self.parent = parent
        }

        // 处理HTTPS证书问题
        func webView(
            _ webView: WKWebView,
            didReceive challenge: URLAuthenticationChallenge,
            completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
        ) {
            if challenge.protectionSpace.host.contains("hzcu.edu.cn"),
               let serverTrust = challenge.protectionSpace.serverTrust {
                completionHandler(.useCredential, URLCredential(trust: serverTrust))
            } else {
                completionHandler(.performDefaultHandling, nil)
            }
        }

        // 页面加载完成时更新地址栏
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            if let url = webView.url?.absoluteString {
                parent.onURLChange?(url)
            }
        }

        // 处理 target="_blank" 和 window.open —— 在当前WebView中打开
        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if navigationAction.targetFrame == nil || !(navigationAction.targetFrame!.isMainFrame) {
                webView.load(navigationAction.request)
            }
            return nil
        }

        // 处理 JavaScript alert()
        func webView(
            _ webView: WKWebView,
            runJavaScriptAlertPanelWithMessage message: String,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping () -> Void
        ) {
            completionHandler()
        }

        // 处理 JavaScript confirm()
        func webView(
            _ webView: WKWebView,
            runJavaScriptConfirmPanelWithMessage message: String,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping (Bool) -> Void
        ) {
            completionHandler(true)
        }

        // 处理 JavaScript prompt()
        func webView(
            _ webView: WKWebView,
            runJavaScriptTextInputPanelWithPrompt prompt: String,
            defaultText: String?,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping (String?) -> Void
        ) {
            completionHandler(defaultText)
        }

        // 允许所有导航请求
        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            decisionHandler(.allow)
        }
    }
}

#Preview {
    ImportView()
}
