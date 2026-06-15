// FavoriteTagsManager.swift
// HitomiReader
//
// Manages a persisted collection of the user's favorite tags.
// Stored as a JSON array in the app's Documents directory.
// Provides toggle, add, remove, and membership-check operations.

import Foundation

@MainActor
final class FavoriteTagsManager: ObservableObject {

    // MARK: - Singleton

    static let shared = FavoriteTagsManager()

    // MARK: - Published

    @Published private(set) var tags: [Tag] = []

    // MARK: - File Path

    private let fileURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("favorite_tags.json")
    }()

    // MARK: - Init

    private init() {
        loadFromDisk()
    }

    // MARK: - Public API

    /// Whether the given tag is in the favorites list.
    func isFavorite(_ tag: Tag) -> Bool {
        tags.contains(where: { $0.displayName == tag.displayName })
    }

    /// Toggles a tag's favorite status. If it's already favorited,
    /// it is removed; otherwise it is added.
    func toggle(_ tag: Tag) {
        if isFavorite(tag) {
            remove(tag)
        } else {
            add(tag)
        }
    }

    /// Adds a tag to favorites if not already present.
    func add(_ tag: Tag) {
        guard !isFavorite(tag) else { return }
        tags.append(tag)
        saveToDisk()
    }

    /// Removes a tag from favorites.
    func remove(_ tag: Tag) {
        tags.removeAll { $0.displayName == tag.displayName }
        saveToDisk()
    }

    /// Removes a tag at the given index set (for SwiftUI List deletion).
    func remove(atOffsets offsets: IndexSet) {
        tags.remove(atOffsets: offsets)
        saveToDisk()
    }

    /// Moves tags in the list (for SwiftUI List reordering).
    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        tags.move(fromOffsets: source, toOffset: destination)
        saveToDisk()
    }

    /// Clears all favorite tags.
    func clearAll() {
        tags.removeAll()
        saveToDisk()
    }

    // MARK: - Persistence

    private func saveToDisk() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(tags)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("[FavoriteTagsManager] Failed to save: \(error.localizedDescription)")
        }
    }

    private func loadFromDisk() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }

        do {
            let data = try Data(contentsOf: fileURL)
            tags = try JSONDecoder().decode([Tag].self, from: data)
        } catch {
            print("[FavoriteTagsManager] Failed to load: \(error.localizedDescription)")
            tags = []
        }
    }
}
