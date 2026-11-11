import Foundation

/// The one-line answer: is this Mac still doing its first-days setup work, or back to normal?
public struct Verdict: Sendable, Equatable {
    public let isSettling: Bool
    public let reasons: [String]

    public var title: String { isSettling ? "Still settling in" : "Back to normal" }

    public static func evaluate(photos: PhotosProgress?, away: AwayReport?, now snapshot: ProcessSnapshot?) -> Verdict {
        var reasons: [String] = []
        if let photos, photos.remaining > max(50, photos.total / 200) {
            reasons.append("Photos has \(Format.count(photos.remaining)) items left to analyze.")
        }
        if let away, away.setupWorkTime >= 3600 {
            reasons.append("While you were away it worked for \(Format.duration(away.backgroundAwake)) instead of sleeping.")
        }
        if let snapshot {
            let busy = snapshot.categories.filter { $0.category.isSetupWork }.reduce(0) { $0 + $1.cpuPercent }
            if busy >= 50 { reasons.append("It's indexing in the background right now.") }
        }
        if reasons.isEmpty {
            return Verdict(isSettling: false, reasons: ["No big setup jobs are left. Background work is at normal levels."])
        }
        return Verdict(isSettling: true, reasons: reasons)
    }
}

public enum Format {
    /// "7h 33m", "47m", "under a minute".
    public static func duration(_ seconds: TimeInterval) -> String {
        let minutes = Int((seconds / 60).rounded())
        if minutes < 1 { return "under a minute" }
        let h = minutes / 60, m = minutes % 60
        if h == 0 { return "\(m)m" }
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }

    public static func count(_ n: Int) -> String {
        n.formatted(.number.grouping(.automatic))
    }

    /// Share of the whole Mac's CPU, from a per-core percentage like Activity Monitor's.
    public static func shareOfMac(_ perCorePercent: Double, cores: Int) -> String {
        let share = perCorePercent / Double(max(cores, 1))
        if share < 1 { return "<1%" }
        return "\(Int(share.rounded()))%"
    }

    public static func percent(_ fraction: Double) -> String {
        // Never round up to 100% while work is left.
        let value = fraction < 1 ? min(99, Int((fraction * 100).rounded(.down))) : 100
        return "\(value)%"
    }
}
