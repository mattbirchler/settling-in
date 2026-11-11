import Foundation

/// A kind of background work macOS does on its own, with a name a person can understand.
public enum BackgroundCategory: String, CaseIterable, Sendable, Codable {
    case photos
    case spotlightFiles
    case spotlightKnowledge
    case intelligence
    case iCloud
    case backup
    case security
    case updates

    public var title: String {
        switch self {
        case .photos: "Photos analysis"
        case .spotlightFiles: "Spotlight file indexing"
        case .spotlightKnowledge: "Spotlight knowledge indexing"
        case .intelligence: "Apple Intelligence"
        case .iCloud: "iCloud and sync"
        case .backup: "Time Machine"
        case .security: "Security scans"
        case .updates: "Software updates"
        }
    }

    public var detail: String {
        switch self {
        case .photos: "Finding faces, objects and text in your library"
        case .spotlightFiles: "Making your files searchable"
        case .spotlightKnowledge: "Indexing mail, messages and events for search"
        case .intelligence: "On-device models and suggestions"
        case .iCloud: "Syncing photos, contacts and files"
        case .backup: "Backing up your Mac"
        case .security: "Checking apps for malware"
        case .updates: "Downloading system components"
        }
    }

    public var symbol: String {
        switch self {
        case .photos: "photo.on.rectangle"
        case .spotlightFiles: "magnifyingglass"
        case .spotlightKnowledge: "text.magnifyingglass"
        case .intelligence: "apple.intelligence"
        case .iCloud: "icloud"
        case .backup: "clock.arrow.circlepath"
        case .security: "checkmark.shield"
        case .updates: "arrow.down.circle"
        }
    }

    /// True for the work a new Mac does once and then mostly stops doing.
    public var isSetupWork: Bool {
        switch self {
        case .photos, .spotlightFiles, .spotlightKnowledge, .intelligence: true
        default: false
        }
    }

    private static let processNames: [String: BackgroundCategory] = [
        "mediaanalysisd": .photos, "mediaanalysisd-access": .photos, "photoanalysisd": .photos,
        "photolibraryd": .photos, "cloudphotod": .photos,
        "mds": .spotlightFiles, "mds_stores": .spotlightFiles, "mdworker": .spotlightFiles,
        "mdworker_shared": .spotlightFiles, "mdbulkimport": .spotlightFiles, "mdsync": .spotlightFiles,
        "corespotlightd": .spotlightFiles,
        "spotlightknowledged": .spotlightKnowledge, "spotlightknowledged.importer": .spotlightKnowledge,
        "spotlightknowledged.updater": .spotlightKnowledge,
        "intelligenceplatformd": .intelligence, "knowledgeconstructiond": .intelligence,
        "siriknowledged": .intelligence, "generativeexperiencesd": .intelligence,
        "modelmanagerd": .intelligence, "intelligencecontextd": .intelligence, "Siri AI": .intelligence,
        "cloudd": .iCloud, "bird": .iCloud, "fileproviderd": .iCloud, "nsurlsessiond": .iCloud,
        "AddressBookSourceSync": .iCloud, "biomesyncd": .iCloud,
        "backupd": .backup, "backupd-helper": .backup,
        "XProtect": .security, "XprotectService": .security, "XProtectPluginService": .security,
        "syspolicyd": .security,
        "softwareupdated": .updates, "mobileassetd": .updates,
    ]

    /// Classifies a running process by its executable path. Copies of these daemons inside
    /// iOS Simulator runtimes are ignored, since they belong to a simulated device.
    public static func forProcess(path: String) -> BackgroundCategory? {
        if path.contains("/CoreSimulator/") || path.contains("SimulatorRuntime") { return nil }
        let name = (path as NSString).lastPathComponent
        return processNames[name]
    }

    /// Classifies a scheduled background task name from the power log,
    /// such as "DASActivity:501:com.apple.mediaanalysisd.photos.full".
    public static func forTask(_ name: String) -> BackgroundCategory? {
        let n = name.lowercased()
        let rules: [(String, BackgroundCategory)] = [
            ("spotlightknowledge", .spotlightKnowledge),
            ("mediaanalysisd", .photos), ("photoanalysisd", .photos), ("photolibraryd", .photos),
            ("cloudphoto", .photos),
            ("corespotlight", .spotlightFiles), ("metadata.mds", .spotlightFiles), ("mdworker", .spotlightFiles),
            ("intelligence", .intelligence), ("knowledgeconstruction", .intelligence), ("siriknowledge", .intelligence),
            ("modelmanager", .intelligence),
            ("addressbook", .iCloud), ("biomesync", .iCloud), ("cloudd", .iCloud), ("cloudkit", .iCloud),
            ("xprotect", .security), ("backupd", .backup),
            ("softwareupdate", .updates), ("mobileasset", .updates),
        ]
        return rules.first { n.contains($0.0) }?.1
    }
}
