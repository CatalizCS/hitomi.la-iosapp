// ReadingStatusManager.swift
// HitomiReader
//
// Manages reading status categories (Want to Read, Reading, Completed)
// for galleries. Stored in reading_statuses.json in the Documents directory.

import Foundation

enum ReadingStatus: String, Codable, CaseIterable, Identifiable {
    case none = "none"
    case wantToRead = "wantToRead"
    case reading = "reading"
    case completed = "completed"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .none: return "No Status"
        case .wantToRead: return "Want to Read"
        case .reading: return "Reading"
        case .completed: return "Completed"
        }
    }
    
    var viDisplayName: String {
        switch self {
        case .none: return "Không có"
        case .wantToRead: return "Muốn đọc"
        case .reading: return "Đang đọc"
        case .completed: return "Đã đọc xong"
        }
    }
}

@MainActor
final class ReadingStatusManager: ObservableObject {
    
    // MARK: - Singleton
    static let shared = ReadingStatusManager()
    
    // MARK: - Published
    @Published private(set) var statuses: [Int: ReadingStatus] = [:] // galleryID -> ReadingStatus
    
    // MARK: - Private Registry
    // Since dictionaries are easy but we also want gallery metadata (e.g. title) to render them
    // in the Library tab without network calls, we will store a list of mini metadata records:
    struct StatusRecord: Codable {
        let galleryID: Int
        let title: String
        let thumbnailURLString: String?
        let status: ReadingStatus
        let timestamp: Date
    }
    
    @Published private(set) var records: [StatusRecord] = []
    
    private let fileURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("reading_statuses.json")
    }()
    
    // MARK: - Init
    private init() {
        loadFromDisk()
    }
    
    // MARK: - Public API
    
    func getStatus(for galleryID: Int) -> ReadingStatus {
        statuses[galleryID] ?? .none
    }
    
    func setStatus(_ status: ReadingStatus, for gallery: Gallery) {
        let galleryID = gallery.id
        
        if status == .none {
            statuses.removeValue(forKey: galleryID)
            records.removeAll { $0.galleryID == galleryID }
        } else {
            statuses[galleryID] = status
            
            // Get thumbnail URL
            var thumbStr: String? = nil
            if let firstImage = gallery.files?.first {
                if let url = try? ImageURLResolver.shared.resolveThumbnailURL(galleryID: gallery.id, image: firstImage) {
                    thumbStr = url.absoluteString
                }
            }
            
            let record = StatusRecord(
                galleryID: galleryID,
                title: gallery.displayTitle,
                thumbnailURLString: thumbStr,
                status: status,
                timestamp: Date()
            )
            
            if let index = records.firstIndex(where: { $0.galleryID == galleryID }) {
                records[index] = record
            } else {
                records.insert(record, at: 0)
            }
        }
        
        saveToDisk()
    }
    
    func getRecords(for status: ReadingStatus) -> [StatusRecord] {
        records.filter { $0.status == status }.sorted(by: { $0.timestamp > $1.timestamp })
    }
    
    func clearAll() {
        statuses.removeAll()
        records.removeAll()
        saveToDisk()
    }
    
    // MARK: - Persistence
    
    private func saveToDisk() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(records)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("[ReadingStatusManager] Failed to save reading statuses: \(error.localizedDescription)")
        }
    }
    
    private func loadFromDisk() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            let loadedRecords = try JSONDecoder().decode([StatusRecord].self, from: data)
            self.records = loadedRecords
            
            var loadedStatuses = [Int: ReadingStatus]()
            for record in loadedRecords {
                loadedStatuses[record.galleryID] = record.status
            }
            self.statuses = loadedStatuses
        } catch {
            print("[ReadingStatusManager] Failed to load reading statuses: \(error.localizedDescription)")
            self.records = []
            self.statuses = [:]
        }
    }
}
