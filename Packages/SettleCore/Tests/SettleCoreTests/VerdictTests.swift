import Foundation
import Testing
@testable import SettleCore

private func photos(remaining: Int, total: Int = 10_000) -> PhotosProgress {
    PhotosProgress(total: total, sharedAlbumItems: 0,
                   stages: [.init(name: "Main analysis", done: total - remaining, total: total)],
                   videosLeft: remaining, photosLeft: 0)
}

private func away(setupMinutes: Double) -> AwayReport {
    AwayReport(start: Date(), end: Date().addingTimeInterval(8 * 3600), asleep: 0, backgroundAwake: 8 * 3600,
               tasks: [.init(category: .photos, duration: setupMinutes * 60), .init(category: .iCloud, duration: 5 * 3600)])
}

@Test func settlingWhilePhotosHasWorkLeft() {
    let v = Verdict.evaluate(photos: photos(remaining: 1_433), away: nil, now: nil)
    #expect(v.isSettling)
    #expect(v.reasons == ["Photos has 1,433 items left to analyze."])
}

@Test func aFewLeftoverItemsDontCount() {
    #expect(!Verdict.evaluate(photos: photos(remaining: 40), away: nil, now: nil).isSettling)
}

@Test func longOvernightSetupWorkCounts() {
    let v = Verdict.evaluate(photos: photos(remaining: 0), away: away(setupMinutes: 90), now: nil)
    #expect(v.isSettling)
    #expect(v.reasons == ["While you were away it worked for 8h instead of sleeping."])
}

@Test func iCloudSyncAloneIsNormal() {
    #expect(!Verdict.evaluate(photos: photos(remaining: 0), away: away(setupMinutes: 10), now: nil).isSettling)
}

@Test func formatsDurations() {
    #expect(Format.duration(20) == "under a minute")
    #expect(Format.duration(47 * 60) == "47m")
    #expect(Format.duration(7 * 3600 + 33 * 60) == "7h 33m")
    #expect(Format.duration(2 * 3600) == "2h")
}

@Test func percentNeverShows100WhileWorkIsLeft() {
    #expect(Format.percent(0.9996) == "99%")
    #expect(Format.percent(1) == "100%")
    #expect(Format.percent(0.978) == "97%")
}

@Test func shareOfMacDividesByCores() {
    #expect(Format.shareOfMac(85, cores: 10) == "9%")
    #expect(Format.shareOfMac(3, cores: 10) == "<1%")
}
