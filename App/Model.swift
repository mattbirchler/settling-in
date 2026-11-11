import Foundation
import Observation
import SettleCore

/// Holds the latest readings and refreshes each source on its own schedule.
@Observable
final class Model {
    var snapshot: ProcessSnapshot?
    var photos: PhotosProgress?
    var photosError: PhotosProgress.ReadError?
    var away: AwayReport?
    var awayLoaded = false
    var history: ProgressHistory
    var lastUpdated: Date?

    private var photosCheckedAt: Date?
    private var awayCheckedAt: Date?
    private var started = false
    private let historyKey = "photosHistory"

    var verdict: Verdict { .evaluate(photos: photos, away: away, now: snapshot) }

    init() {
        if let data = UserDefaults.standard.data(forKey: historyKey),
           let saved = try? JSONDecoder().decode(ProgressHistory.self, from: data) {
            history = saved
        } else {
            history = ProgressHistory()
        }
    }

    func start() {
        guard !started else { return }
        started = true
        Task { await refresh(force: true) }
        Task {
            while true {
                try? await Task.sleep(for: .seconds(5))
                await refresh(force: false)
            }
        }
    }

    /// Processes every call (cheap), Photos every 2 minutes, the power log every 15 minutes (it takes several seconds).
    func refresh(force: Bool) async {
        let now = Date()
        if let snap = try? await Task.detached(operation: { try ProcessSnapshot.capture() }).value {
            snapshot = snap
        }
        if force || photosCheckedAt.map({ now.timeIntervalSince($0) > 120 }) ?? true {
            photosCheckedAt = now
            await refreshPhotos()
        }
        if force || awayCheckedAt.map({ now.timeIntervalSince($0) > 900 }) ?? true {
            awayCheckedAt = now
            away = try? await Task.detached(priority: .utility, operation: { try PowerLog.read() }).value
            awayLoaded = true
        }
        lastUpdated = Date()
    }

    private func refreshPhotos() async {
        let result = await Task.detached(priority: .utility) { () -> Result<PhotosProgress, PhotosProgress.ReadError> in
            do throws(PhotosProgress.ReadError) { return .success(try PhotosProgress.read()) } catch { return .failure(error) }
        }.value
        switch result {
        case .success(let progress):
            photos = progress
            photosError = nil
            history.record(progress.remaining)
            if let data = try? JSONEncoder().encode(history) { UserDefaults.standard.set(data, forKey: historyKey) }
        case .failure(let error):
            photosError = error
        }
    }
}
