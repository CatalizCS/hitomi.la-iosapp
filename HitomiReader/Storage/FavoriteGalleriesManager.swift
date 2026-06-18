// FavoriteGalleriesManager.swift
// HitomiReader
//
// Manages a persisted collection of the user's favorite galleries (comics).
// Saved to favorite_galleries.json in the Documents directory.

import Foundation

@MainActor
final class FavoriteGalleriesManager: ObservableObject {
    
    // MARK: - Singleton
    static let shared = FavoriteGalleriesManager()
    
    // MARK: - Published
    @Published private(set) var galleries: [Gallery] = []
    
    // MARK: - File Path
    private let fileURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("favorite_galleries.json")
    }()
    
    // MARK: - Init
    private init() {
        loadFromDisk()
    }
    
    // MARK: - Public API
    
    func isFavorite(id: Int) -> Bool {
        galleries.contains(where: { $0.id == id })
    }
    
    func toggle(_ gallery: Gallery) {
        if isFavorite(id: gallery.id) {
            remove(id: gallery.id)
        } else {
            add(gallery)
        }
    }
    
    func add(_ gallery: Gallery) {
        guard !isFavorite(id: gallery.id) else { return }
        galleries.insert(gallery, at: 0) // Prepend newer favorites
        saveToDisk()
    }
    
    func remove(id: Int) {
        galleries.removeAll { $0.id == id }
        saveToDisk()
    }
    
    func clearAll() {
        galleries.removeAll()
        saveToDisk()
    }
    
    // MARK: - Persistence
    
    private func saveToDisk() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(galleries)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("[FavoriteGalleriesManager] Failed to save: \(error.localizedDescription)")
        }
    }
    
    private func loadFromDisk() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            galleries = try JSONDecoder().decode([Gallery].self, from: data)
        } catch {
            print("[FavoriteGalleriesManager] Failed to load: \(error.localizedDescription)")
            galleries = []
        }
    }
}
