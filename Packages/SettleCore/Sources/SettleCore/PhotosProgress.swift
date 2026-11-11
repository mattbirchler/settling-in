import Foundation
import SQLite3

/// How far Photos has gotten analyzing the library, read from its private database without changing it.
public struct PhotosProgress: Sendable, Equatable {
    public struct Stage: Sendable, Equatable, Identifiable {
        public var id: String { name }
        public let name: String
        public let done: Int
        public let total: Int
        public init(name: String, done: Int, total: Int) {
            self.name = name; self.done = done; self.total = total
        }
        public var remaining: Int { total - done }
        public var fraction: Double { total == 0 ? 1 : Double(done) / Double(total) }
    }

    /// Items in your own library (Shared Album photos are counted separately).
    public let total: Int
    /// Photos from Shared Albums. macOS doesn't fully analyze these, so they're left out of the progress.
    public let sharedAlbumItems: Int
    /// The main analysis pass first, then the more specific stages.
    public let stages: [Stage]
    public let videosLeft: Int
    public let photosLeft: Int

    public init(total: Int, sharedAlbumItems: Int, stages: [Stage], videosLeft: Int, photosLeft: Int) {
        self.total = total; self.sharedAlbumItems = sharedAlbumItems; self.stages = stages
        self.videosLeft = videosLeft; self.photosLeft = photosLeft
    }

    public var main: Stage? { stages.first }
    public var remaining: Int { main?.remaining ?? 0 }
    public var fraction: Double { main?.fraction ?? 1 }

    public enum ReadError: Error, Equatable {
        /// macOS blocked access. The app needs Full Disk Access.
        case needsFullDiskAccess
        case libraryNotFound
        case unreadable(String)
    }

    public static var defaultLibraryDatabase: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Pictures/Photos Library.photoslibrary/database/Photos.sqlite")
    }

    public static func read(database: URL = defaultLibraryDatabase) throws(ReadError) -> PhotosProgress {
        let path = database.path
        let fd = open(path, O_RDONLY)
        if fd < 0 {
            throw errno == EPERM || errno == EACCES ? .needsFullDiskAccess : .libraryNotFound
        }
        close(fd)

        var db: OpaquePointer?
        guard sqlite3_open_v2(path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK, let db else {
            sqlite3_close(db)
            throw .unreadable("Couldn't open the Photos database")
        }
        defer { sqlite3_close(db) }
        sqlite3_busy_timeout(db, 2000)
        do {
            return try PhotosQuery(db: db).run()
        } catch {
            throw .unreadable(error.message)
        }
    }
}

private struct SQLError: Error { let message: String }

/// Apple doesn't document this schema and it changes between macOS versions, so every column is checked before use.
private struct PhotosQuery {
    let db: OpaquePointer

    func columns(_ table: String) throws(SQLError) -> Set<String> {
        Set(try rows("PRAGMA table_info(\(table))").compactMap { $0.count > 1 ? $0[1] : nil })
    }

    func rows(_ sql: String) throws(SQLError) -> [[String]] {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw SQLError(message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        var result: [[String]] = []
        while true {
            let rc = sqlite3_step(stmt)
            if rc == SQLITE_DONE { break }
            guard rc == SQLITE_ROW else { throw SQLError(message: String(cString: sqlite3_errmsg(db))) }
            result.append((0..<sqlite3_column_count(stmt)).map { i in
                sqlite3_column_text(stmt, i).map { String(cString: $0) } ?? ""
            })
        }
        return result
    }

    func int(_ sql: String) throws(SQLError) -> Int { Int(try rows(sql).first?.first ?? "") ?? 0 }

    func run() throws(SQLError) -> PhotosProgress {
        let asset = try columns("ZASSET")
        guard asset.contains("Z_PK") else { throw SQLError(message: "This Photos library format isn't supported") }
        let media = try columns("ZMEDIAANALYSISASSETATTRIBUTES")
        let extra = try columns("ZADDITIONALASSETATTRIBUTES")

        var filters = ["1=1"]
        if asset.contains("ZTRASHEDSTATE") { filters.append("a.ZTRASHEDSTATE = 0") }
        let shared = asset.contains("ZSAVEDASSETTYPE") ? "a.ZSAVEDASSETTYPE = 4" : "0"
        let joins = """
            FROM ZASSET a
            \(media.isEmpty ? "" : "LEFT JOIN ZMEDIAANALYSISASSETATTRIBUTES m ON m.ZASSET = a.Z_PK")
            \(extra.isEmpty ? "" : "LEFT JOIN ZADDITIONALASSETATTRIBUTES x ON x.ZASSET = a.Z_PK")
            WHERE \(filters.joined(separator: " AND "))
            """
        let own = "\(joins) AND NOT (\(shared))"

        let sharedCount = try int("SELECT count(*) \(joins) AND \(shared)")
        let total = try int("SELECT count(*) \(own)")

        // (label, table alias, column, needs current version). The main pass gets re-run when Apple ships
        // a new model, so an old version number there means "not done yet". For the others any value counts.
        let candidates: [(String, String, Set<String>, String, Bool)] = [
            ("Main analysis", "m", media, "ZMEDIAANALYSISVERSION", true),
            ("Scenes and objects", "x", extra, "ZSCENEANALYSISVERSION", false),
            ("Faces", "x", extra, "ZFACEANALYSISVERSION", false),
            ("Text in images", "m", media, "ZCHARACTERRECOGNITIONVERSION", false),
            ("Search and captions", "m", media, "ZIMAGECAPTIONVERSION", true),
            ("Visual search", "m", media, "ZVISUALSEARCHVERSION", false),
        ]
        var stages: [PhotosProgress.Stage] = []
        var mainDone = ""
        for (label, alias, cols, column, needsCurrent) in candidates where cols.contains(column) {
            let col = "coalesce(\(alias).\(column), 0)"
            var doneCondition = "\(col) > 0"
            if needsCurrent {
                // The most common non-zero value is the version most of the library is already on.
                let current = try int("SELECT \(col) v \(own) AND \(col) > 0 GROUP BY v ORDER BY count(*) DESC LIMIT 1")
                if current > 0 { doneCondition = "\(col) >= \(current)" }
            }
            let done = try int("SELECT count(*) \(own) AND \(doneCondition)")
            stages.append(.init(name: label, done: done, total: total))
            if mainDone.isEmpty { mainDone = doneCondition }
        }

        var videosLeft = 0, photosLeft = 0
        if !mainDone.isEmpty, asset.contains("ZKIND") {
            for row in try rows("SELECT a.ZKIND, count(*) \(own) AND NOT (\(mainDone)) GROUP BY a.ZKIND") {
                if row.first == "1" { videosLeft += Int(row[1]) ?? 0 } else { photosLeft += Int(row[1]) ?? 0 }
            }
        }
        return PhotosProgress(total: total, sharedAlbumItems: sharedCount, stages: stages,
                              videosLeft: videosLeft, photosLeft: photosLeft)
    }
}

/// Remembers how many items were left at past checks, to estimate the pace and time remaining.
public struct ProgressHistory: Sendable, Codable, Equatable {
    public struct Point: Sendable, Codable, Equatable {
        public let date: Date
        public let remaining: Int
        public init(date: Date, remaining: Int) {
            self.date = date; self.remaining = remaining
        }
    }
    public private(set) var points: [Point] = []

    public init(points: [Point] = []) { self.points = points }

    public mutating func record(_ remaining: Int, at date: Date = Date()) {
        if let last = points.last, last.remaining == remaining, date.timeIntervalSince(last.date) < 15 * 60 { return }
        points.append(Point(date: date, remaining: remaining))
        points.removeAll { date.timeIntervalSince($0.date) > 3 * 86400 }
    }

    /// Items finished per hour over roughly the last six hours, or nil without enough history.
    public func itemsPerHour(now: Date = Date()) -> Double? {
        guard let latest = points.last else { return nil }
        let window = points.filter { now.timeIntervalSince($0.date) <= 6 * 3600 }
        guard let first = window.first else { return nil }
        let hours = latest.date.timeIntervalSince(first.date) / 3600
        let finished = first.remaining - latest.remaining
        guard hours >= 0.5, finished > 0 else { return nil }
        return Double(finished) / hours
    }

    public func hoursLeft(now: Date = Date()) -> Double? {
        guard let rate = itemsPerHour(now: now), let latest = points.last else { return nil }
        return Double(latest.remaining) / rate
    }
}
