import Foundation

/// CPU use of one category of background work at a moment in time.
public struct CategoryUsage: Sendable, Identifiable, Equatable {
    public var id: BackgroundCategory { category }
    public let category: BackgroundCategory
    /// Percent of one CPU core, as Activity Monitor shows it. Can exceed 100.
    public let cpuPercent: Double
    public let processNames: [String]
}

public struct ProcessSnapshot: Sendable, Equatable {
    public let categories: [CategoryUsage]
    /// Everything else, mostly your own apps.
    public let otherCPUPercent: Double
    public let coreCount: Int

    public var backgroundCPUPercent: Double { categories.reduce(0) { $0 + $1.cpuPercent } }
    public func usage(_ category: BackgroundCategory) -> CategoryUsage? {
        categories.first { $0.category == category }
    }

    /// Parses `ps -Ao pid=,pcpu=,comm=` output.
    public static func parse(psOutput: String, coreCount: Int) -> ProcessSnapshot {
        var cpu: [BackgroundCategory: Double] = [:]
        var names: [BackgroundCategory: Set<String>] = [:]
        var other = 0.0
        for line in psOutput.split(separator: "\n") {
            let parts = line.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
            guard parts.count == 3, Int(parts[0]) != nil, let pcpu = Double(parts[1]) else { continue }
            let path = String(parts[2])
            if let category = BackgroundCategory.forProcess(path: path) {
                cpu[category, default: 0] += pcpu
                if pcpu > 0 { names[category, default: []].insert((path as NSString).lastPathComponent) }
            } else {
                other += pcpu
            }
        }
        let usages = cpu.map { CategoryUsage(category: $0.key, cpuPercent: $0.value, processNames: names[$0.key, default: []].sorted()) }
            .sorted { $0.cpuPercent > $1.cpuPercent }
        return ProcessSnapshot(categories: usages, otherCPUPercent: other, coreCount: coreCount)
    }

    public static func capture() throws -> ProcessSnapshot {
        let output = try Shell.run("/bin/ps", ["-Ao", "pid=,pcpu=,comm="])
        return parse(psOutput: output, coreCount: ProcessInfo.processInfo.activeProcessorCount)
    }
}
