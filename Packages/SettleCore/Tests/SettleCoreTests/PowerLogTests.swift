import Foundation
import Testing
@testable import SettleCore

private func line(_ time: String, _ type: String, _ message: String) -> String {
    "2026-11-10 \(time) -0600 \(type.padding(toLength: 20, withPad: " ", startingAt: 0))\t\(message)"
}
private func line11(_ time: String, _ type: String, _ message: String) -> String {
    line(time, type, message).replacingOccurrences(of: "2026-11-10", with: "2026-11-11")
}
private let now = PowerLog.parseDate("2026-11-11 08:00:00 -0600")!

private let night = [
    line("21:00:00", "Wake", "DarkWake to FullWake from Deep Idle [CDNVA] : due to UserActivity"),
    line("22:00:00", "Sleep", "Entering Sleep state due to 'Clamshell Sleep':TCPKeepAlive=active"),
    line("22:30:00", "DarkWake", "DarkWake from Deep Idle [CDNP] : due to rtc/Maintenance"),
    line("23:30:00", "Sleep", "Entering Sleep state due to 'Maintenance Sleep'"),
    line11("00:30:00", "DarkWake", "DarkWake from Deep Idle [CDNP] : due to rtc/Maintenance"),
    // A notification lights the Mac up for 6 seconds, then it drops back to background work.
    line11("01:00:00", "Wake", "DarkWake to FullWake from Deep Idle [CDNVAP] : due to Notification"),
    line11("01:00:06", "Sleep", "Entering DarkWake state due to 'Notification Wake Back to Sleep'"),
    line11("02:00:00", "Wake", "DarkWake to FullWake from Deep Idle [CDNVA] : due to UserActivity Assertion"),
    line("23:20:00", "Assertions", "PID 457(dasd) Released BackgroundTask \"DASActivity:501:com.apple.mediaanalysisd.photos.full\" 00:50:00  id:0x0xb0000a050 [System: PrevIdle]"),
    line11("01:30:00", "Assertions", "PID 457(dasd) Released BackgroundTask \"DASActivity:501:com.apple.spotlightknowledged.task\" 01:00:00  id:0x1 [System: PrevIdle]"),
    // Started long before the away period; only the overlapping part should count.
    line11("02:30:00", "Assertions", "PID 1479(cloudd) Released SystemIsActive \"NSURLSessionTask ABC\" 10:00:00  id:0x2 [System: PrevIdle]"),
    // Overlaps the first Photos task, so it should not add time.
    line("23:10:00", "Assertions", "PID 457(dasd) Released BackgroundTask \"DASActivity:501:com.apple.mediaanalysisd.photos.person\" 00:20:00  id:0x4 [System: PrevIdle]"),
    line("23:00:00", "Assertions", "PID 1563(corespeechd) Created PreventSystemSleep \"com.apple.corespeech.powerassertion\" 00:00:00  id:0x3"),
].joined(separator: "\n")

@Test func findsAwayPeriodAndSplitsSleepFromBackground() throws {
    let report = try #require(PowerLog.parse(night, now: now))
    #expect(report.start == PowerLog.parseDate("2026-11-10 22:00:00 -0600"))
    #expect(report.end == PowerLog.parseDate("2026-11-11 02:00:00 -0600"))
    #expect(report.asleep == 90 * 60)            // 22:00 to 22:30 and 23:30 to 00:30
    #expect(report.backgroundAwake == 150 * 60)  // 22:30 to 23:30 and 00:30 to 02:00, including the 6 second blip
}

@Test func attributesTaskTimeClippedToAwayPeriod() throws {
    let report = try #require(PowerLog.parse(night, now: now))
    #expect(report.time(for: .photos) == 50 * 60)
    #expect(report.time(for: .spotlightKnowledge) == 60 * 60)
    #expect(report.time(for: .iCloud) == 4 * 3600)
    #expect(report.setupWorkTime == 110 * 60)
}

@Test func skipsShortLidCloses() throws {
    let log = night + "\n" + [
        line11("07:00:00", "Sleep", "Entering Sleep state due to 'Clamshell Sleep'"),
        line11("07:05:00", "Wake", "DarkWake to FullWake from Deep Idle [CDNVA] : due to HID Activity"),
    ].joined(separator: "\n")
    let report = try #require(PowerLog.parse(log, now: now))
    #expect(report.end == PowerLog.parseDate("2026-11-11 02:00:00 -0600"))
}

@Test func noAwayPeriodReturnsNil() {
    #expect(PowerLog.parse(line("21:00:00", "Wake", "DarkWake to FullWake"), now: now) == nil)
}

@Test func parsesDatesWithOffsets() {
    let d = PowerLog.parseDate("2026-11-11 06:48:10 -0600")!
    #expect(d.timeIntervalSince1970 == 1_794_401_290)
}

@Test func readsRealLog() throws {
    // Smoke test against this Mac's log. It should parse quickly and not crash; a report may or may not exist.
    let clock = ContinuousClock()
    var report: AwayReport?
    let elapsed = try clock.measure { report = try PowerLog.read() }
    #expect(elapsed < .seconds(30))
    if let r = report {
        print("REAL away \(r.start) to \(r.end): asleep \(Int(r.asleep / 60))m, background \(Int(r.backgroundAwake / 60))m")
        for t in r.tasks { print("REAL   \(t.category.title): \(Int(t.duration / 60))m") }
    }
}
