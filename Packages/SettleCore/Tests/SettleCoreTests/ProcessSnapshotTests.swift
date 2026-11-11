import Testing
@testable import SettleCore

private let sample = """
  476  39.9 /System/Library/PrivateFrameworks/SkyLight.framework/Resources/WindowServer
 1200  85.0 /System/Library/PrivateFrameworks/MediaAnalysis.framework/Versions/A/mediaanalysisd
 1201  12.5 /System/Library/PrivateFrameworks/PhotoLibraryServices.framework/Versions/A/Support/photolibraryd
  433   3.0 /System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/Metadata.framework/Versions/A/Support/mds
44252   2.0 /System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/Metadata.framework/Versions/A/Support/mdworker_shared
26303   0.0 /usr/libexec/spotlightknowledged.importer
68052  50.0 /private/var/run/com.apple.security.cryptexd/mnt/com.apple.iPhoneOS.SimulatorRuntime-v24/Library/Developer/CoreSimulator/Profiles/Runtimes/iOS 27.2.simruntime/Contents/Resources/RuntimeRoot/usr/libexec/spotlightknowledged.updater
72144   2.7 /Applications/Rex Beta.app/Contents/MacOS/Rex
"""

@Test func groupsProcessesIntoCategories() {
    let snap = ProcessSnapshot.parse(psOutput: sample, coreCount: 10)
    #expect(snap.usage(.photos)?.cpuPercent == 97.5)
    #expect(snap.usage(.photos)?.processNames == ["mediaanalysisd", "photolibraryd"])
    #expect(snap.usage(.spotlightFiles)?.cpuPercent == 5.0)
    #expect(snap.categories.first?.category == .photos)
}

@Test func idleCategoryIsPresentButHasNoNames() {
    let snap = ProcessSnapshot.parse(psOutput: sample, coreCount: 10)
    #expect(snap.usage(.spotlightKnowledge)?.cpuPercent == 0)
    #expect(snap.usage(.spotlightKnowledge)?.processNames == [])
}

@Test func simulatorCopiesCountAsOther() {
    let snap = ProcessSnapshot.parse(psOutput: sample, coreCount: 10)
    #expect(abs(snap.otherCPUPercent - (39.9 + 50.0 + 2.7)) < 0.001)
}

@Test func appPathsWithSpacesParse() {
    let snap = ProcessSnapshot.parse(psOutput: "  9  1.0 /Applications/My App.app/Contents/MacOS/My App\n", coreCount: 8)
    #expect(snap.otherCPUPercent == 1.0)
}

@Test func classifiesPowerLogTaskNames() {
    #expect(BackgroundCategory.forTask("DASActivity:501:com.apple.mediaanalysisd.photos.full") == .photos)
    #expect(BackgroundCategory.forTask("DASActivity:501:com.apple.spotlightknowledged.pipelines.lssr5eventsandordersbackground.journal-processing") == .spotlightKnowledge)
    #expect(BackgroundCategory.forTask("DASActivity:501:com.apple.AddressBook.ScheduledSync") == .iCloud)
    #expect(BackgroundCategory.forTask("DASActivity:501:com.apple.XProtect.PluginService.agent.scan") == .security)
    #expect(BackgroundCategory.forTask("DASActivity:0:com.apple.signpost.signpost_reporter_activity") == nil)
}

@Test func captureRunsAgainstRealSystem() throws {
    let snap = try ProcessSnapshot.capture()
    #expect(snap.coreCount > 0)
}
