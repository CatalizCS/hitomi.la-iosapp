// DownloadManager.swift
// HitomiReader
//
// Manages the queue, progress, and persistence of downloaded galleries (comics)
// for offline reading. Stored under Documents/downloads/{galleryID}/{pageIndex}.webp

import Foundation
import UIKit

@MainActor
final class DownloadManager: ObservableObject {
    
    // MARK: - Singleton
    static let shared = DownloadManager()
    
    // MARK: - Published States
    @Published private(set) var downloadedGalleries: [Gallery] = []
    @Published private(set) var activeDownloads: [Int: Double] = [:] // galleryID -> progress (0.0 to 1.0)
    
    // MARK: - Private Constants
    private let fileManager = FileManager.default
    private let registryURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("downloaded_galleries.json")
    }()
    
    private let downloadsDirectory: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("downloads", isDirectory: true)
    }()
    
    // MARK: - Init
    private init() {
        createDirectoryIfNeeded(downloadsDirectory)
        loadRegistry()
    }
    
    // MARK: - Public API
    
    func isDownloaded(galleryID: Int) -> Bool {
        downloadedGalleries.contains(where: { $0.id == galleryID })
    }
    
    func isDownloading(galleryID: Int) -> Bool {
        activeDownloads[galleryID] != nil
    }
    
    func getProgress(for galleryID: Int) -> Double? {
        activeDownloads[galleryID]
    }
    
    /// Starts downloading a gallery.
    func download(_ gallery: Gallery) {
        guard !isDownloaded(galleryID: gallery.id) else { return }
        guard !isDownloading(galleryID: gallery.id) else { return }
        
        activeDownloads[gallery.id] = 0.0
        
        Task {
            do {
                try await performDownload(gallery)
                activeDownloads[gallery.id] = nil
                downloadedGalleries.insert(gallery, at: 0)
                saveRegistry()
            } catch {
                print("[DownloadManager] Failed to download gallery \(gallery.id): \(error.localizedDescription)")
                activeDownloads[gallery.id] = nil
                deleteLocalFiles(for: gallery.id) // Clean up partial download
            }
        }
    }
    
    /// Deletes downloaded files and removes the gallery from registry.
    func deleteDownload(galleryID: Int) {
        downloadedGalleries.removeAll { $0.id == galleryID }
        saveRegistry()
        deleteLocalFiles(for: galleryID)
    }
    
    /// Returns the local file URL for an image if downloaded, nil otherwise.
    func getLocalImageURL(for galleryID: Int, pageIndex: Int) -> URL? {
        guard isDownloaded(galleryID: galleryID) else { return nil }
        let fileURL = downloadsDirectory
            .appendingPathComponent("\(galleryID)")
            .appendingPathComponent("\(pageIndex).webp")
        
        if fileManager.fileExists(atPath: fileURL.path) {
            return fileURL
        }
        return nil
    }
    
    // MARK: - Download Worker
    
    private func performDownload(_ gallery: Gallery) async throws {
        guard let files = gallery.files, !files.isEmpty else {
            throw DownloadError.noFiles
        }
        
        let galleryDir = downloadsDirectory.appendingPathComponent("\(gallery.id)", isDirectory: true)
        createDirectoryIfNeeded(galleryDir)
        
        // Save metadata.json inside the gallery directory
        let metadataURL = galleryDir.appendingPathComponent("metadata.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let metadataData = try encoder.encode(gallery)
        try metadataData.write(to: metadataURL, options: .atomic)
        
        // Setup specialized session (with hitomi.la headers)
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = [
            "Referer": "https://hitomi.la/",
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1"
        ]
        let session = URLSession(configuration: config)
        
        let total = files.count
        var completed = 0
        
        // Download in parallel batches of 5 to avoid network/memory congestion
        let batchSize = 5
        for i in stride(from: 0, to: total, by: batchSize) {
            let end = min(i + batchSize, total)
            let indices = Array(i..<end)
            
            try await withThrowingTaskGroup(of: (Int, Data).self) { group in
                for index in indices {
                    let image = files[index]
                    group.addTask {
                        // 1. Resolve URL
                        let url = try await HitomiAPI.shared.getImageURL(image: image, galleryID: gallery.id)
                        
                        // 2. Fetch data
                        let (data, response) = try await session.data(from: url)
                        guard let httpResponse = response as? HTTPURLResponse,
                              (200...299).contains(httpResponse.statusCode) else {
                            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                            throw DownloadError.httpError(statusCode: code)
                        }
                        
                        return (index, data)
                    }
                }
                
                for try await (index, data) in group {
                    // 3. Write data to disk
                    let fileURL = galleryDir.appendingPathComponent("\(index).webp")
                    try data.write(to: fileURL, options: .atomic)
                    
                    completed += 1
                    // Update progress on main thread
                    let progress = Double(completed) / Double(total)
                    activeDownloads[gallery.id] = progress
                }
            }
            
            // Short rest between batches
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
    }
    
    // MARK: - Helpers
    
    private func createDirectoryIfNeeded(_ url: URL) {
        if !fileManager.fileExists(atPath: url.path) {
            try? fileManager.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        }
    }
    
    private func deleteLocalFiles(for galleryID: Int) {
        let galleryDir = downloadsDirectory.appendingPathComponent("\(galleryID)", isDirectory: true)
        try? fileManager.removeItem(at: galleryDir)
    }
    
    private func saveRegistry() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(downloadedGalleries)
            try data.write(to: registryURL, options: .atomic)
        } catch {
            print("[DownloadManager] Failed to save downloaded registry: \(error.localizedDescription)")
        }
    }
    
    private func loadRegistry() {
        guard fileManager.fileExists(atPath: registryURL.path) else { return }
        do {
            let data = try Data(contentsOf: registryURL)
            downloadedGalleries = try JSONDecoder().decode([Gallery].self, from: data)
        } catch {
            print("[DownloadManager] Failed to load downloaded registry: \(error.localizedDescription)")
            downloadedGalleries = []
        }
    }
}

// MARK: - Errors

enum DownloadError: LocalizedError {
    case noFiles
    case httpError(statusCode: Int)
    
    var errorDescription: String? {
        switch self {
        case .noFiles:
            return "Gallery does not contain any image files."
        case .httpError(let code):
            return "HTTP Error \(code) downloading image."
        }
    }
}
