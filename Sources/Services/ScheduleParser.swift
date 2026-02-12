import Foundation

/// 正方教务系统课表数据解析器
struct ScheduleParser {
    
    /// 解析课表数据（正方教务系统返回的JSON格式）
    static func parse(data: Data) -> [ParsedCourse] {
        var results: [ParsedCourse] = []

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let kbList = json["kbList"] as? [[String: Any]] else {
            return parseHTML(data: data)
        }

        for item in kbList {
            guard let name = item["kcmc"] as? String,
                  let dayStr = item["xqj"] as? String,
                  let dayOfWeek = Int(dayStr) else {
                continue
            }

            let teacher = item["xm"] as? String ?? ""
            let classroom = item["cdmc"] as? String ?? ""
            let jcs = item["jcs"] as? String ?? ""
            let sections = jcs.split(separator: "-").compactMap { Int($0) }
            let startSection = sections.first ?? 1
            let endSection = sections.last ?? startSection
            let zcd = item["zcd"] as? String ?? "1-20周"
            let weekRanges = parseWeeks(zcd)

            for range in weekRanges {
                results.append(ParsedCourse(
                    name: name, teacher: teacher, classroom: classroom,
                    dayOfWeek: dayOfWeek, startSection: startSection, endSection: endSection,
                    startWeek: range.start, endWeek: range.end, weekType: range.type
                ))
            }
        }
        return results
    }

    /// 从JavaScript提取的JSON字符串解析课程
    /// 返回 (课程列表, 表格总节次数)
    static func parseFromJS(jsonString: String) -> ([ParsedCourse], Int) {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) else {
            return ([], 0)
        }

        // 支持新格式 {courses: [...], totalSections: N} 和旧格式 [...]
        let array: [[String: Any]]
        var totalSections = 0

        if let obj = json as? [String: Any] {
            array = obj["courses"] as? [[String: Any]] ?? []
            totalSections = obj["totalSections"] as? Int ?? 0
        } else if let arr = json as? [[String: Any]] {
            array = arr
        } else {
            return ([], 0)
        }

        var results: [ParsedCourse] = []
        for item in array {
            guard let name = item["name"] as? String,
                  let dayOfWeek = item["dayOfWeek"] as? Int,
                  let startSection = item["startSection"] as? Int,
                  let endSection = item["endSection"] as? Int else {
                continue
            }

            let teacher = item["teacher"] as? String ?? ""
            let classroom = item["classroom"] as? String ?? ""
            let weekText = item["weeks"] as? String ?? "1-20周"
            let weekRanges = parseWeeks(weekText)

            for range in weekRanges {
                results.append(ParsedCourse(
                    name: name, teacher: teacher, classroom: classroom,
                    dayOfWeek: dayOfWeek, startSection: startSection, endSection: endSection,
                    startWeek: range.start, endWeek: range.end, weekType: range.type
                ))
            }
        }
        return (results, totalSections)
    }

    /// 解析周次字符串
    static func parseWeeks(_ text: String) -> [(start: Int, end: Int, type: Int)] {
        var results: [(start: Int, end: Int, type: Int)] = []
        let parts = text.components(separatedBy: ",")
        for part in parts {
            let cleaned = part.trimmingCharacters(in: .whitespaces)
            var weekType = 0
            if cleaned.contains("单") { weekType = 1 }
            else if cleaned.contains("双") { weekType = 2 }

            let numbersOnly = cleaned.replacingOccurrences(of: "[^0-9-]", with: "", options: .regularExpression)
            let numbers = numbersOnly.split(separator: "-").compactMap { Int($0) }
            if numbers.count >= 2 {
                results.append((start: numbers[0], end: numbers[1], type: weekType))
            } else if numbers.count == 1 {
                results.append((start: numbers[0], end: numbers[0], type: weekType))
            }
        }
        return results.isEmpty ? [(start: 1, end: 20, type: 0)] : results
    }

    /// 备用：HTML解析
    private static func parseHTML(data: Data) -> [ParsedCourse] {
        guard let html = String(data: data, encoding: .utf8) else { return [] }
        var results: [ParsedCourse] = []

        // 匹配所有 td_wrap 的 id 和内容
        // td id格式: {dayOfWeek}-{section}, 如 "3-1" = 星期三第1节
        let tdPattern = #"<td[^>]*id="(\d+)-(\d+)"[^>]*class="td_wrap"[^>]*>(.*?)</td>"#
        guard let tdRegex = try? NSRegularExpression(pattern: tdPattern, options: .dotMatchesLineSeparators) else {
            return results
        }

        let tdMatches = tdRegex.matches(in: html, range: NSRange(html.startIndex..., in: html))
        for match in tdMatches {
            guard let dayRange = Range(match.range(at: 1), in: html),
                  let sectionRange = Range(match.range(at: 2), in: html),
                  let contentRange = Range(match.range(at: 3), in: html),
                  let dayOfWeek = Int(html[dayRange]),
                  let startSection = Int(html[sectionRange]) else { continue }

            let content = String(html[contentRange])
            if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { continue }

            // 提取课程名
            let titlePattern = #"class="title"[^>]*><font[^>]*>(.*?)</font>"#
            guard let titleRegex = try? NSRegularExpression(pattern: titlePattern, options: .dotMatchesLineSeparators),
                  let titleMatch = titleRegex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
                  let titleRange = Range(titleMatch.range(at: 1), in: content) else { continue }

            let name = String(content[titleRange]).trimmingCharacters(in: .whitespacesAndNewlines)

            // 提取节次/周次: title="节/周"
            var weeks = "1-20周"
            var endSection = startSection
            let timePattern = #"title="节/周".*?</span></font></span><font[^>]*>\s*\((\d+)-(\d+)节\)(.*?)</font>"#
            if let timeRegex = try? NSRegularExpression(pattern: timePattern, options: .dotMatchesLineSeparators),
               let timeMatch = timeRegex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)) {
                if let startRange = Range(timeMatch.range(at: 1), in: content),
                   let endRange = Range(timeMatch.range(at: 2), in: content),
                   let weeksRange = Range(timeMatch.range(at: 3), in: content) {
                    let _ = Int(content[startRange]) // startSection already from td id
                    endSection = Int(content[endRange]) ?? startSection
                    weeks = String(content[weeksRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }

            // 提取教室: title="上课地点"
            var classroom = ""
            let roomPattern = #"title="上课地点".*?</span></font></span><font[^>]*>\s*(.*?)</font>"#
            if let roomRegex = try? NSRegularExpression(pattern: roomPattern, options: .dotMatchesLineSeparators),
               let roomMatch = roomRegex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
               let roomRange = Range(roomMatch.range(at: 1), in: content) {
                classroom = String(content[roomRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            }

            // 提取教师: title="教师"
            var teacher = ""
            let teacherPattern = #"title="教师.*?".*?</span></font></span><font[^>]*>\s*(.*?)</font>"#
            if let teacherRegex = try? NSRegularExpression(pattern: teacherPattern, options: .dotMatchesLineSeparators),
               let teacherMatch = teacherRegex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
               let teacherRange = Range(teacherMatch.range(at: 1), in: content) {
                teacher = String(content[teacherRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            }

            let weekRanges = parseWeeks(weeks)
            for range in weekRanges {
                results.append(ParsedCourse(
                    name: name, teacher: teacher, classroom: classroom,
                    dayOfWeek: dayOfWeek, startSection: startSection, endSection: endSection,
                    startWeek: range.start, endWeek: range.end, weekType: range.type
                ))
            }
        }

        return results
    }

    /// 用于注入WebView的JavaScript脚本
    /// 针对正方教务系统V9.0课表页面，从表格DOM中提取课程数据
    /// 表格id: kbgrid_table_0, td id格式: {星期}-{节次}
    static let extractionJS = """
    (function() {
        var results = [];
        var totalSections = 0;
        
        // 方法1: 从表格视图(#table1)的td中提取
        // td的id格式: "{dayOfWeek}-{section}", 如 "3-1" = 星期三第1节
        var table = document.getElementById('kbgrid_table_0');
        if (table) {
            // 从所有td.td_wrap中获取表格的总节次数
            var allCells = table.querySelectorAll('td.td_wrap');
            for (var i = 0; i < allCells.length; i++) {
                var cid = allCells[i].getAttribute('id');
                if (!cid) continue;
                var cp = cid.split('-');
                if (cp.length === 2) {
                    var sec = parseInt(cp[1]);
                    if (!isNaN(sec) && sec > totalSections) totalSections = sec;
                }
            }
            
            var cells = table.querySelectorAll('td.td_wrap');
            for (var i = 0; i < cells.length; i++) {
                var cell = cells[i];
                var cellId = cell.getAttribute('id');
                if (!cellId) continue;
                
                var parts = cellId.split('-');
                if (parts.length !== 2) continue;
                
                var dayOfWeek = parseInt(parts[0]);
                var startSection = parseInt(parts[1]);
                if (isNaN(dayOfWeek) || isNaN(startSection)) continue;
                
                // 检查是否有课程内容
                var conDivs = cell.querySelectorAll('.timetable_con');
                if (conDivs.length === 0) continue;
                
                for (var j = 0; j < conDivs.length; j++) {
                    var con = conDivs[j];
                    
                    // 课程名: span.title > font
                    var titleEl = con.querySelector('.title font');
                    if (!titleEl) titleEl = con.querySelector('.title');
                    var name = titleEl ? titleEl.innerText.trim() : '';
                    if (!name) continue;
                    
                    // 节次和周次: 包含 "节/周" tooltip的p
                    var endSection = startSection;
                    var weeks = '1-20周';
                    var allP = con.querySelectorAll('p');
                    for (var k = 0; k < allP.length; k++) {
                        var tooltip = allP[k].querySelector('[data-toggle="tooltip"][title="节/周"]');
                        if (tooltip) {
                            var pText = allP[k].innerText.trim();
                            // 格式: (1-4节)17周 或 (1-4节)1-8周,10-15周
                            var sectionMatch = pText.match(/\\((\\d+)-(\\d+)节\\)/);
                            if (sectionMatch) {
                                startSection = parseInt(sectionMatch[1]);
                                endSection = parseInt(sectionMatch[2]);
                            }
                            // 周次在节次后面
                            var weekPart = pText.replace(/\\(\\d+-\\d+节\\)/, '').trim();
                            if (weekPart) weeks = weekPart;
                            break;
                        }
                    }
                    
                    // 教室: 包含 "上课地点" tooltip的p
                    var classroom = '';
                    for (var k = 0; k < allP.length; k++) {
                        var tooltip = allP[k].querySelector('[title="上课地点"]');
                        if (tooltip) {
                            classroom = allP[k].innerText.trim();
                            // 去掉校区前缀 "浙大城市学院"
                            classroom = classroom.replace(/浙大城市学院\\s*/, '').trim();
                            break;
                        }
                    }
                    
                    // 教师: 包含 "教师" tooltip的p
                    var teacher = '';
                    for (var k = 0; k < allP.length; k++) {
                        var tooltip = allP[k].querySelector('[title*="教师"]');
                        if (tooltip) {
                            teacher = allP[k].innerText.trim();
                            break;
                        }
                    }
                    
                    results.push({
                        name: name,
                        teacher: teacher,
                        classroom: classroom,
                        weeks: weeks,
                        dayOfWeek: dayOfWeek,
                        startSection: startSection,
                        endSection: endSection
                    });
                }
            }
        }
        
        // 方法2: 如果表格视图没数据，尝试列表视图(#table2)
        if (results.length === 0) {
            var listBodies = document.querySelectorAll('tbody[id^="xq_"]');
            listBodies.forEach(function(tbody) {
                var xqId = tbody.getAttribute('id'); // "xq_1" = 星期一
                var dayOfWeek = parseInt(xqId.replace('xq_', ''));
                
                var rows = tbody.querySelectorAll('tr');
                rows.forEach(function(row) {
                    var jcTd = row.querySelector('td[id^="jc_"]');
                    if (!jcTd) return;
                    
                    // jc id格式: "jc_{day}-{startSection}-{endSection}"
                    var jcId = jcTd.getAttribute('id');
                    var jcParts = jcId.replace('jc_', '').split('-');
                    if (jcParts.length < 3) return;
                    
                    var startSection = parseInt(jcParts[1]);
                    var endSection = parseInt(jcParts[2]);
                    
                    var con = row.querySelector('.timetable_con');
                    if (!con) return;
                    
                    var titleEl = con.querySelector('.title font');
                    if (!titleEl) titleEl = con.querySelector('.title');
                    var name = titleEl ? titleEl.innerText.trim() : '';
                    if (!name) return;
                    
                    // 在列表视图中，周次格式: "周数：1-8周,10-15周"
                    var weeks = '1-20周';
                    var pEls = con.querySelectorAll('p font, p');
                    for (var k = 0; k < pEls.length; k++) {
                        var t = pEls[k].innerText;
                        if (t && t.indexOf('周数') >= 0) {
                            weeks = t.replace(/.*周数[：:]\\s*/, '').trim();
                            break;
                        }
                    }
                    
                    // 教室
                    var classroom = '';
                    for (var k = 0; k < pEls.length; k++) {
                        var t = pEls[k].innerText;
                        if (t && t.indexOf('上课地点') >= 0) {
                            classroom = t.replace(/.*上课地点[：:]\\s*/, '').replace(/浙大城市学院\\s*/, '').trim();
                            break;
                        }
                    }
                    
                    // 教师
                    var teacher = '';
                    for (var k = 0; k < pEls.length; k++) {
                        var t = pEls[k].innerText;
                        if (t && t.indexOf('教师') >= 0) {
                            teacher = t.replace(/.*教师\\s*[：:]\\s*/, '').trim();
                            break;
                        }
                    }
                    
                    results.push({
                        name: name,
                        teacher: teacher,
                        classroom: classroom,
                        weeks: weeks,
                        dayOfWeek: dayOfWeek,
                        startSection: startSection,
                        endSection: endSection
                    });
                });
            });
        }
        
        return JSON.stringify({courses: results, totalSections: totalSections});
    })();
    """;
}
