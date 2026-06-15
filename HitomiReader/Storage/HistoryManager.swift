// HistoryManager.swift
// HitomiReader
//
// Stores the user's reading history as an array of HistoryEntry objects
// persisted to a JSON file in the Documents directory.
// Most-recently-read entries appear first.

import Foundation

// MARK: - History Entry

struct HistoryEntry: Codable, Identifiable, Hashable {
    let galleryID: Int
    var title: String
    var thumbnailURLString: String?   // Persisted as a string (URLs aren't Codable by default)
    var lastPage: Int                 // Zero-indexed page the user was on
    var totalPages: Int
    var timestamp: Date               // Last time this gallery was opened/updated

    var id: Int { galleryID }

    /// Reading progress as a fraction (0.0 – 1.0).
    var progress: Double {
        guard totalPages > 0 else { return 0 }
        return Double(lastPage + 1) / Double(totalPages)
    }

    var thumbnailURL: URL? {
        guard let str = thumbnailURLString else { return nil }
        return URL(string: str)
    }
}

// MARK: - History Manager

@MainActor
final class HistoryManager: ObservableObject {

    // MARK: - Singleton

    static let shared = HistoryManager()

    // MARK: - Published

    @Published private(set) var entries: [HistoryEntry] = []

    // MARK: - File Path

    private let fileURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("reading_history.json")
    }()

    // MARK: - Init

    private init() {
        loadFromDisk()
    }

    // MARK: - Public API

    /// Adds or updates a history entry for the given gallery.
    /// If the gallery already exists in history, it updates the page
    /// and moves it to the front. Otherwise, a new entry is prepended.
    func upsert(
        galleryID: Int,
        title: String,
        thumbnailURL: URL? = nil,
        lastPage: Int,
        totalPages: Int
    ) {
        if let index = entries.firstIndex(where: { $0.galleryID == galleryID }) {
            var entry = entries[index]
            entry.title = title
            entry.lastPage = lastPage
            entry.totalPages = totalPages
            entry.timestamp = Date()
            if let url = thumbnailURL {
                entry.thumbnailURLString = url.absoluteString
            }
            entries.remove(at: index)
            entries.insert(entry, at: 0)
        } else {
            let entry = HistoryEntry(
                galleryID: galleryID,
                title: title,
                thumbnailURLString: thumbnailURL?.absoluteString,
                lastPage: lastPage,
                totalPages: totalPages,
                timestamp: Date()
            )
            entries.insert(entry, at: 0)
        }

        // Keep history to a reasonable size (500 entries max).
        if entries.count > 500 {
            entries = Array(entries.prefix(500))
        }

        saveToDisk()
    }

    /// Returns the history entry for a gallery ID, if it exists.
    func entry(for galleryID: Int) -> HistoryEntry? {
        entries.first { $0.galleryID == galleryID }
    }

    /// Removes a single entry by gallery ID.
    func remove(galleryID: Int) {
        entries.removeAll { $0.galleryID == galleryID }
        saveToDisk()
    }

    /// Clears all reading history.
    func clearAll() {
        entries.removeAll()
        saveToDisk()
    }

    // MARK: - Persistence

    private func saveToDisk() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(entries)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("[HistoryManager] Failed to save: \(error.localizedDescription)")
        }
    }

    private func loadFromDisk() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            entries = try decoder.decode([HistoryEntry].self, from: data)
        } catch {
            print("[HistoryManager] Failed to load: \(error.localizedDescription)")
            entries = []
        }
    }
}
