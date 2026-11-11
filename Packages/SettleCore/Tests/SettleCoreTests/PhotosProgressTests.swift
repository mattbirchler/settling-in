import Foundation
import SQLite3
import Testing
@testable import SettleCore

/// Builds a small database shaped like the Photos schema.
private func makeLibrary() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appending(path: "settle-\(UUID().uuidString).sqlite")
    var db: OpaquePointer?
    sqlite3_open(url.path, &db)
    defer { sqlite3_close(db) }
    var sql = """
    CREATE TABLE ZASSET (Z_PK INTEGER PRIMARY KEY, ZKIND INTEGER, ZTRASHEDSTATE INTEGER, ZSAVEDASSETTYPE INTEGER);
    CREATE TABLE ZMEDIAANALYSISASSETATTRIBUTES (Z_PK INTEGER PRIMARY KEY, ZASSET INTEGER, ZMEDIAANALYSISVERSION INTEGER,
        ZCHARACTERRECOGNITIONVERSION INTEGER, ZIMAGECAPTIONVERSION INTEGER, ZVISUALSEARCHVERSION INTEGER);
    CREATE TABLE ZADDITIONALASSETATTRIBUTES (Z_PK INTEGER PRIMARY KEY, ZASSET INTEGER, ZSCENEANALYSISVERSION INTEGER, ZFACEANALYSISVERSION INTEGER);
    """
    // 1-6: own photos fully analyzed on version 77.
    // 7: own photo on old version 1. 8-9: own videos never analyzed.
    // 10: trashed. 11-12: Shared Album photos, never analyzed.
    let assets: [(Int, Int, Int, Int, Int)] = [ // id, kind, trashed, savedType, mainVersion
        (1,0,0,6,77),(2,0,0,6,77),(3,0,0,6,77),(4,0,0,6,77),(5,0,0,6,77),(6,0,0,6,77),
        (7,0,0,6,1),(8,1,0,6,0),(9,1,0,6,0),(10,0,1,6,0),(11,0,0,4,0),(12,0,0,4,0),
    ]
    for (id, kind, trashed, saved, version) in assets {
        sql += "INSERT INTO ZASSET VALUES (\(id), \(kind), \(trashed), \(saved));"
        let ocr = version > 0 ? 9 : 0
        sql += "INSERT INTO ZMEDIAANALYSISASSETATTRIBUTES VALUES (\(id), \(id), \(version), \(ocr), \(version), \(version > 0 ? 317 : 0));"
        sql += "INSERT INTO ZADDITIONALASSETATTRIBUTES VALUES (\(id), \(id), \(version > 0 ? 5 : 0), \(id <= 5 ? 3 : 0));"
    }
    #expect(sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK)
    return url
}

@Test func countsOwnLibraryAndSplitsOutSharedAlbums() throws {
    let p = try PhotosProgress.read(database: try makeLibrary())
    #expect(p.total == 9)
    #expect(p.sharedAlbumItems == 2)
}

@Test func oldModelVersionCountsAsNotDone() throws {
    let p = try PhotosProgress.read(database: try makeLibrary())
    #expect(p.main?.name == "Main analysis")
    #expect(p.main?.done == 6)
    #expect(p.remaining == 3)
    #expect(p.videosLeft == 2)
    #expect(p.photosLeft == 1)
}

@Test func otherStagesAcceptAnyVersion() throws {
    let p = try PhotosProgress.read(database: try makeLibrary())
    let text = try #require(p.stages.first { $0.name == "Text in images" })
    #expect(text.done == 7) // version 1 and 77 rows both have OCR
    let faces = try #require(p.stages.first { $0.name == "Faces" })
    #expect(faces.done == 5)
}

@Test func missingLibraryIsReported() {
    #expect(throws: PhotosProgress.ReadError.libraryNotFound) {
        try PhotosProgress.read(database: URL(fileURLWithPath: "/nonexistent/Photos.sqlite"))
    }
}

@Test func historyEstimatesPace() {
    let start = Date(timeIntervalSince1970: 1_000_000)
    var h = ProgressHistory()
    h.record(1000, at: start)
    h.record(800, at: start.addingTimeInterval(3600))
    h.record(600, at: start.addingTimeInterval(7200))
    let now = start.addingTimeInterval(7200)
    #expect(h.itemsPerHour(now: now) == 200)
    #expect(h.hoursLeft(now: now) == 3)
}

@Test func historyNeedsProgressToEstimate() {
    let start = Date(timeIntervalSince1970: 1_000_000)
    var h = ProgressHistory()
    h.record(500, at: start)
    h.record(500, at: start.addingTimeInterval(3600))
    #expect(h.itemsPerHour(now: start.addingTimeInterval(3600)) == nil)
}

@Test func readsRealLibrary() throws {
    // Runs against this Mac's library when the test runner can see it.
    guard let p = try? PhotosProgress.read() else { return }
    print("REAL photos total \(p.total) shared \(p.sharedAlbumItems) videosLeft \(p.videosLeft) photosLeft \(p.photosLeft)")
    for s in p.stages { print("REAL   \(s.name): \(s.done)/\(s.total)") }
}
