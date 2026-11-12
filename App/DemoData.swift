import Foundation
import SettleCore

extension Model {
    /// Sample readings for screenshots, shown with --demo. Nothing is read from this Mac.
    func loadDemoData() {
        snapshot = ProcessSnapshot(
            categories: [
                CategoryUsage(category: .photos, cpuPercent: 212, processNames: ["mediaanalysisd"]),
                CategoryUsage(category: .spotlightKnowledge, cpuPercent: 64, processNames: ["spotlightknowledged"]),
                CategoryUsage(category: .iCloud, cpuPercent: 18, processNames: ["cloudd"]),
            ],
            otherCPUPercent: 40, coreCount: 10)

        let total = 24_180
        photos = PhotosProgress(
            total: total, sharedAlbumItems: 312,
            stages: [
                .init(name: "Main analysis", done: total - 2_946, total: total),
                .init(name: "Scenes and objects", done: total - 1_120, total: total),
                .init(name: "Faces", done: total - 1_304, total: total),
                .init(name: "Text in images", done: total - 85, total: total),
                .init(name: "Search and captions", done: total - 410, total: total),
                .init(name: "Visual search", done: total, total: total),
            ],
            videosLeft: 1_840, photosLeft: 1_106)

        let now = Date()
        history = ProgressHistory(points: [
            .init(date: now.addingTimeInterval(-3 * 3600), remaining: 3_786),
            .init(date: now, remaining: 2_946),
        ])

        let calendar = Calendar.current
        let morning = calendar.date(bySettingHour: 7, minute: 15, second: 0, of: now) ?? now
        let end = morning > now ? morning.addingTimeInterval(-86_400) : morning
        away = AwayReport(
            start: end.addingTimeInterval(-8.5 * 3600), end: end,
            asleep: 2.25 * 3600, backgroundAwake: 6.25 * 3600,
            tasks: [
                .init(category: .photos, duration: 5.6 * 3600),
                .init(category: .spotlightKnowledge, duration: 3.1 * 3600),
                .init(category: .iCloud, duration: 1.4 * 3600),
                .init(category: .security, duration: 180),
            ])
        awayLoaded = true
        lastUpdated = now
    }

    /// Sample readings for a Mac that has finished its setup work, shown with --demo-done.
    func loadDemoDoneData() {
        snapshot = ProcessSnapshot(
            categories: [CategoryUsage(category: .iCloud, cpuPercent: 0.4, processNames: ["cloudd"])],
            otherCPUPercent: 60, coreCount: 10)

        let total = 24_180
        photos = PhotosProgress(
            total: total, sharedAlbumItems: 312,
            stages: ["Main analysis", "Scenes and objects", "Faces", "Text in images", "Search and captions", "Visual search"]
                .map { .init(name: $0, done: total, total: total) },
            videosLeft: 0, photosLeft: 0)
        history = ProgressHistory()

        let now = Date()
        let morning = Calendar.current.date(bySettingHour: 7, minute: 15, second: 0, of: now) ?? now
        let end = morning > now ? morning.addingTimeInterval(-86_400) : morning
        away = AwayReport(
            start: end.addingTimeInterval(-8.5 * 3600), end: end,
            asleep: 8.1 * 3600, backgroundAwake: 0.4 * 3600,
            tasks: [
                .init(category: .iCloud, duration: 14 * 60),
                .init(category: .photos, duration: 6 * 60),
                .init(category: .security, duration: 2 * 60),
            ])
        awayLoaded = true
        lastUpdated = now
    }
}
