import AppKit
import ServiceManagement
import SwiftUI
import SettleCore

struct PanelView: View {
    let model: Model

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            StatusHeader(verdict: model.verdict)
            Divider()
            RightNowSection(snapshot: model.snapshot)
            PhotosSection(photos: model.photos, error: model.photosError, history: model.history)
            SpotlightSection(snapshot: model.snapshot, away: model.away)
            AwaySection(away: model.away, loaded: model.awayLoaded)
            Divider()
            Footer(model: model)
        }
        .padding(16)
        .frame(width: 380)
    }
}

// MARK: - Header

struct StatusHeader: View {
    let verdict: Verdict

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: verdict.isSettling ? "hourglass" : "checkmark.circle.fill")
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(verdict.isSettling ? Color.orange : Color.green)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 3) {
                Text(verdict.title).font(.title3.weight(.semibold))
                ForEach(verdict.reasons, id: \.self) { reason in
                    Text(reason).font(.callout).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

// MARK: - Shared pieces

struct SectionTitle: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text.uppercased())
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .tracking(0.5)
    }
}

struct Card<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 8) { content }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 8))
    }
}

struct Placeholder: View {
    let text: String
    var body: some View {
        Text(text).font(.callout).foregroundStyle(.secondary)
    }
}

// MARK: - Right now

struct RightNowSection: View {
    let snapshot: ProcessSnapshot?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionTitle("Right now")
            Card {
                if let snapshot {
                    let active = snapshot.categories.filter { $0.cpuPercent >= 1 }
                    if active.isEmpty {
                        Placeholder(text: "Background work is idle.")
                    } else {
                        ForEach(active) { usage in
                            CategoryRow(usage: usage, cores: snapshot.coreCount)
                        }
                    }
                    Text("Your apps and everything else: \(Format.shareOfMac(snapshot.otherCPUPercent, cores: snapshot.coreCount)) of CPU")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Placeholder(text: "Checking…")
                }
            }
        }
    }
}

struct CategoryRow: View {
    let usage: CategoryUsage
    let cores: Int

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: usage.category.symbol)
                .frame(width: 20)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(usage.category.title).font(.callout.weight(.medium))
                Text(usage.category.detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(Format.shareOfMac(usage.cpuPercent, cores: cores))
                .font(.callout.monospacedDigit())
                .help("Share of your Mac's total CPU")
        }
    }
}

// MARK: - Photos

struct PhotosSection: View {
    let photos: PhotosProgress?
    let error: PhotosProgress.ReadError?
    let history: ProgressHistory
    @State private var showStages = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionTitle("Photos analysis")
            Card {
                if let photos {
                    content(photos)
                } else if error == .needsFullDiskAccess {
                    accessPrompt
                } else if let error {
                    Placeholder(text: message(for: error))
                } else {
                    Placeholder(text: "Reading your library…")
                }
            }
        }
    }

    @ViewBuilder private func content(_ photos: PhotosProgress) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(photos.remaining == 0 ? "All analyzed" : "\(Format.percent(photos.fraction)) analyzed")
                .font(.callout.weight(.medium))
            Spacer()
            Text("\(Format.count(photos.total)) items").font(.caption).foregroundStyle(.secondary)
        }
        ProgressView(value: photos.fraction).tint(photos.remaining == 0 ? .green : .accentColor)
        if photos.remaining > 0 {
            Text(leftText(photos)).font(.caption).foregroundStyle(.secondary)
            if let rate = history.itemsPerHour(), let hours = history.hoursLeft() {
                Text("About \(Format.count(Int(rate))) an hour lately, so roughly \(Format.duration(hours * 3600)) of work left.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        DisclosureGroup(isExpanded: $showStages) {
            VStack(spacing: 6) {
                ForEach(photos.stages.dropFirst()) { stage in
                    HStack {
                        Text(stage.name).font(.caption)
                        Spacer()
                        Text(stage.remaining == 0 ? "Done" : "\(Format.count(stage.remaining)) left")
                            .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.top, 4)
        } label: {
            Text("Details").font(.caption)
        }
        if photos.sharedAlbumItems > 0 {
            Text("\(Format.count(photos.sharedAlbumItems)) Shared Album photos aren't counted. macOS doesn't fully analyze them.")
                .font(.caption2).foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func leftText(_ p: PhotosProgress) -> String {
        var parts: [String] = []
        if p.videosLeft > 0 { parts.append("\(Format.count(p.videosLeft)) \(p.videosLeft == 1 ? "video" : "videos")") }
        if p.photosLeft > 0 { parts.append("\(Format.count(p.photosLeft)) \(p.photosLeft == 1 ? "photo" : "photos")") }
        return parts.joined(separator: " and ") + " left. Videos take the longest."
    }

    private var accessPrompt: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Settle needs Full Disk Access to read your Photos library's progress. It only reads, and never changes anything.")
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
            Button("Open Privacy Settings") {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_AllFiles")!)
            }
            Text("Turn on Settle in the list, then reopen this menu.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func message(for error: PhotosProgress.ReadError) -> String {
        switch error {
        case .libraryNotFound: "No Photos library found in your Pictures folder."
        case .unreadable(let detail): "Couldn't read the Photos library. \(detail)"
        case .needsFullDiskAccess: ""
        }
    }
}

// MARK: - Spotlight

struct SpotlightSection: View {
    let snapshot: ProcessSnapshot?
    let away: AwayReport?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionTitle("Spotlight")
            Card {
                row(symbol: "magnifyingglass", title: "File search",
                    status: busy(.spotlightFiles) ? "Indexing now" : "Up to date",
                    note: nil)
                row(symbol: "text.magnifyingglass", title: "Knowledge indexing",
                    status: busy(.spotlightKnowledge) ? "Running now" : "Idle",
                    note: knowledgeNote)
            }
        }
    }

    private func busy(_ category: BackgroundCategory) -> Bool {
        (snapshot?.usage(category)?.cpuPercent ?? 0) >= 5
    }

    private var knowledgeNote: String {
        let time = away?.time(for: .spotlightKnowledge) ?? 0
        let ran = time >= 60 ? "Ran for \(Format.duration(time)) while you were away. " : ""
        return ran + "Apple doesn't share progress for this one."
    }

    private func row(symbol: String, title: String, status: String, note: String?) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol).frame(width: 20).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                HStack {
                    Text(title).font(.callout.weight(.medium))
                    Spacer()
                    Text(status).font(.callout).foregroundStyle(.secondary)
                }
                if let note {
                    Text(note).font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

// MARK: - While you were away

struct AwaySection: View {
    let away: AwayReport?
    let loaded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionTitle("While you were away")
            Card {
                if let away {
                    content(away)
                } else if loaded {
                    Placeholder(text: "No long stretch away from your Mac in the last two days.")
                } else {
                    Placeholder(text: "Reading the sleep log…")
                }
            }
        }
    }

    @ViewBuilder private func content(_ away: AwayReport) -> some View {
        Text(timeRange(away)).font(.callout.weight(.medium))
        SleepBar(asleep: away.asleep, background: away.backgroundAwake)
        HStack(spacing: 14) {
            legend(color: .indigo.opacity(0.6), text: "Asleep \(Format.duration(away.asleep))")
            legend(color: .orange, text: "Working \(Format.duration(away.backgroundAwake))")
        }
        if !away.tasks.isEmpty {
            VStack(spacing: 5) {
                ForEach(away.tasks) { task in
                    HStack(spacing: 8) {
                        Image(systemName: task.category.symbol).frame(width: 18).foregroundStyle(.secondary)
                        Text(task.category.title).font(.caption)
                        Spacer()
                        Text(Format.duration(task.duration)).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.top, 2)
        }
    }

    private func legend(color: Color, text: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(text).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func timeRange(_ away: AwayReport) -> String {
        let time = Date.FormatStyle(date: .omitted, time: .shortened)
        let sameDay = Calendar.current.isDate(away.start, inSameDayAs: away.end)
        let start = sameDay ? away.start.formatted(time) : away.start.formatted(.dateTime.weekday(.abbreviated).hour().minute())
        return "\(start) to \(away.end.formatted(time)), \(Format.duration(away.duration))"
    }
}

struct SleepBar: View {
    let asleep: TimeInterval
    let background: TimeInterval

    var body: some View {
        GeometryReader { geo in
            let total = max(asleep + background, 1)
            HStack(spacing: 2) {
                Rectangle().fill(.indigo.opacity(0.6)).frame(width: max(0, geo.size.width * asleep / total - 1))
                Rectangle().fill(.orange)
            }
            .clipShape(.rect(cornerRadius: 3))
        }
        .frame(height: 8)
    }
}

// MARK: - Footer

struct Footer: View {
    let model: Model
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        HStack {
            if let updated = model.lastUpdated {
                Text("Updated \(updated.formatted(date: .omitted, time: .standard))")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("Open at login", isOn: $launchAtLogin)
                .toggleStyle(.checkbox)
                .font(.caption)
                .onChange(of: launchAtLogin) { _, on in
                    do {
                        if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                    } catch {
                        launchAtLogin = SMAppService.mainApp.status == .enabled
                    }
                }
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .font(.caption)
        }
    }
}
