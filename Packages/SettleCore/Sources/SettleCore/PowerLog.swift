import Foundation

/// What the Mac did during the most recent stretch when you weren't using it, read from `pmset -g log`.
public struct AwayReport: Sendable, Equatable {
    public let start: Date
    public let end: Date
    /// Time actually asleep.
    public let asleep: TimeInterval
    /// Time awake with the screen off, doing background work.
    public let backgroundAwake: TimeInterval
    /// How long each kind of work was running during the stretch. Different kinds can run at once, so these can add up to more than the stretch.
    public let tasks: [TaskTime]

    public var duration: TimeInterval { end.timeIntervalSince(start) }
    public var setupWorkTime: TimeInterval {
        tasks.filter { $0.category.isSetupWork }.reduce(0) { $0 + $1.duration }
    }
    public func time(for category: BackgroundCategory) -> TimeInterval {
        tasks.first { $0.category == category }?.duration ?? 0
    }

    public struct TaskTime: Sendable, Equatable, Identifiable {
        public var id: BackgroundCategory { category }
        public let category: BackgroundCategory
        public let duration: TimeInterval
    }
}

public enum PowerLog {
    enum State { case awake, background, asleep }

    struct Transition { let date: Date; let state: State }
    struct TaskSpan { let category: BackgroundCategory; let start: Date; let end: Date }

    /// Awake stretches shorter than this (a notification lighting the Mac up for a few seconds) don't end an away period.
    static let blipLimit: TimeInterval = 3 * 60
    /// Away periods shorter than this (closing the lid to move rooms) are skipped.
    static let minimumAway: TimeInterval = 30 * 60

    public static func read(now: Date = Date()) throws -> AwayReport? {
        let text = try Shell.run("/usr/bin/pmset", ["-g", "log"])
        return parse(text, now: now)
    }

    /// Finds the most recent away period of at least 30 minutes in the last two days.
    public static func parse(_ text: String, now: Date = Date()) -> AwayReport? {
        let cutoff = now.addingTimeInterval(-48 * 3600)
        var transitions: [Transition] = []
        var spans: [TaskSpan] = []

        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            guard line.count > 30, let date = parseDate(line.prefix(25)), date >= cutoff else { continue }
            let rest = line.dropFirst(26)
            guard let tab = rest.firstIndex(of: "\t") else { continue }
            let type = rest[..<tab].trimmingCharacters(in: .whitespaces)
            let message = rest[rest.index(after: tab)...]
            switch type {
            case "Sleep":
                transitions.append(Transition(date: date, state: message.hasPrefix("Entering DarkWake") ? .background : .asleep))
            case "DarkWake":
                transitions.append(Transition(date: date, state: .background))
            case "Wake":
                transitions.append(Transition(date: date, state: .awake))
            case "Assertions":
                if let span = parseTaskSpan(message, releasedAt: date) { spans.append(span) }
            default:
                break
            }
        }
        return report(transitions: transitions, spans: spans, now: now)
    }

    static func report(transitions: [Transition], spans: [TaskSpan], now: Date) -> AwayReport? {
        guard !transitions.isEmpty else { return nil }
        // Turn transitions into back-to-back intervals, then absorb short awake blips into the background state.
        var intervals: [(state: State, start: Date, end: Date)] = []
        for (i, t) in transitions.enumerated() {
            let end = i + 1 < transitions.count ? transitions[i + 1].date : now
            if end > t.date { intervals.append((t.state, t.date, end)) }
        }
        for i in intervals.indices where intervals[i].state == .awake
            && intervals[i].end.timeIntervalSince(intervals[i].start) < blipLimit
            && i > 0 && i < intervals.count - 1 {
            intervals[i].state = .background
        }
        // Group consecutive non-awake intervals into away periods; keep the newest long one.
        var periods: [[(state: State, start: Date, end: Date)]] = []
        var current: [(state: State, start: Date, end: Date)] = []
        for interval in intervals {
            if interval.state == .awake {
                if !current.isEmpty { periods.append(current); current = [] }
            } else {
                current.append(interval)
            }
        }
        if !current.isEmpty { periods.append(current) }
        guard let away = periods.last(where: { $0.last!.end.timeIntervalSince($0.first!.start) >= minimumAway }) else { return nil }

        let start = away.first!.start, end = away.last!.end
        var asleep: TimeInterval = 0, background: TimeInterval = 0
        for i in away {
            let length = i.end.timeIntervalSince(i.start)
            if i.state == .asleep { asleep += length } else { background += length }
        }
        // Merge each category's spans so parallel tasks (dozens of small iCloud transfers at once) count once.
        var byCategory: [BackgroundCategory: TimeInterval] = [:]
        for (category, group) in Dictionary(grouping: spans, by: \.category) {
            let clipped = group.compactMap { s -> (Date, Date)? in
                let a = max(s.start, start), b = min(s.end, end)
                return b > a ? (a, b) : nil
            }.sorted { $0.0 < $1.0 }
            var total: TimeInterval = 0
            var run: (Date, Date)?
            for interval in clipped {
                if let r = run, interval.0 <= r.1 {
                    run = (r.0, max(r.1, interval.1))
                } else {
                    if let r = run { total += r.1.timeIntervalSince(r.0) }
                    run = interval
                }
            }
            if let r = run { total += r.1.timeIntervalSince(r.0) }
            byCategory[category] = total
        }
        let tasks = byCategory.map { AwayReport.TaskTime(category: $0.key, duration: $0.value) }
            .filter { $0.duration >= 60 }
            .sorted { $0.duration > $1.duration }
        return AwayReport(start: start, end: end, asleep: asleep, backgroundAwake: background, tasks: tasks)
    }

    /// Reads a line like `PID 457(dasd) Released BackgroundTask "DASActivity:501:com.apple.x" 00:22:06  id:...`.
    static func parseTaskSpan(_ message: Substring, releasedAt: Date) -> TaskSpan? {
        guard message.contains(") Released "),
              let open = message.firstIndex(of: "("), let close = message.firstIndex(of: ")"), open < close,
              let q1 = message.firstIndex(of: "\"") else { return nil }
        let afterQ1 = message.index(after: q1)
        guard let q2 = message[afterQ1...].firstIndex(of: "\"") else { return nil }
        let process = String(message[message.index(after: open)..<close])
        let name = String(message[afterQ1..<q2])
        guard let category = BackgroundCategory.forTask(name) ?? BackgroundCategory.forProcess(path: process) else { return nil }
        let after = message[message.index(after: q2)...].drop { $0 == " " }
        let parts = after.prefix { $0 != " " }.split(separator: ":")
        guard parts.count == 3, let h = Double(parts[0]), let m = Double(parts[1]), let s = Double(parts[2]) else { return nil }
        let duration = h * 3600 + m * 60 + s
        return TaskSpan(category: category, start: releasedAt.addingTimeInterval(-duration), end: releasedAt)
    }

    /// Parses "2026-11-10 22:26:39 -0600" without a DateFormatter, since the log has ~180,000 lines.
    static func parseDate(_ s: Substring) -> Date? {
        let c = Array(s.utf8)
        guard c.count == 25 else { return nil }
        func num(_ from: Int, _ len: Int) -> Int? {
            var v = 0
            for i in from..<(from + len) {
                let d = Int(c[i]) - 48
                guard d >= 0 && d <= 9 else { return nil }
                v = v * 10 + d
            }
            return v
        }
        guard let y = num(0, 4), let mo = num(5, 2), let d = num(8, 2), let h = num(11, 2), let mi = num(14, 2),
              let se = num(17, 2), let oh = num(21, 2), let om = num(23, 2) else { return nil }
        let sign = c[20] == UInt8(ascii: "-") ? -1 : 1
        // Days since 1970-01-01 (Howard Hinnant's civil-from-days, inverted).
        let yy = mo <= 2 ? y - 1 : y
        let era = (yy >= 0 ? yy : yy - 399) / 400
        let yoe = yy - era * 400
        let doy = (153 * (mo + (mo > 2 ? -3 : 9)) + 2) / 5 + d - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        let days = era * 146097 + doe - 719468
        let local = days * 86400 + h * 3600 + mi * 60 + se
        let offset = sign * (oh * 3600 + om * 60)
        return Date(timeIntervalSince1970: TimeInterval(local - offset))
    }
}
