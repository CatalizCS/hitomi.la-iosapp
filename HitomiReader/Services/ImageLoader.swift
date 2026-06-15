// ImageLoader.swift
// HitomiReader
//
// ObservableObject that asynchronously loads a single image from a URL,
// injecting the required `Referer: https://hitomi.la/` header.
//
// Usage in SwiftUI:
//   @StateObject var loader = ImageLoader()
//   Image(uiImage: loader.image ?? UIImage())
//       .onAppear { loader.load(url: imageURL) }

import Foundation
import UIKit
import Combine

@MainActor
final class ImageLoader: ObservableObject {

    // MARK: - Published state

    @Published var image: UIImage?
    @Published var isLoading = false
    @Published var error: Error?

    // MARK: - Private

    /// Dedicated URLSession with a large image cache.
    private static let imageSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = [
            "Referer": "https://hitomi.la/"
        ]
        // 100 MB memory, 500 MB disk — images are large.
        config.urlCache = URLCache(
            memoryCapacity: 100 * 1024 * 1024,
            diskCapacity: 500 * 1024 * 1024
        )
        config.requestCachePolicy = .returnCacheDataElseLoad
        return URLSession(configuration: config)
    }()

    /// The currently running download task (for cancellation).
    private var currentTask: Task<Void, Never>?

    /// The URL that is currently loaded (avoids redundant fetches).
    private var loadedURL: URL?

    // MARK: - Public API

    /// Loads an image from the given URL.
    ///
    /// If the same URL is already loaded or in-progress, this is a no-op.
    /// Call `cancel()` first if you need to force a reload.
    ///
    /// - Parameter url: The image URL to fetch.
    func load(url: URL) {
        // Skip if we've already loaded this exact URL.
        guard url != loadedURL else { return }

        cancel()
        loadedURL = url

        isLoading = true
        error = nil

        currentTask = Task {
            do {
                let request = URLRequest(url: url)
                let (data, response) = try await Self.imageSession.data(for: request)

                // Check for cancellation.
                try Task.checkCancellation()

                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    throw ImageLoaderError.httpError
                }

                guard let uiImage = UIImage(data: data) else {
                    throw ImageLoaderError.invalidImageData
                }

                self.image = uiImage
                self.isLoading = false
            } catch is CancellationError {
                // Task was cancelled — do nothing.
            } catch {
                self.error = error
                self.isLoading = false
            }
        }
    }

    /// Cancels any in-progress download.
    func cancel() {
        currentTask?.cancel()
        currentTask = nil
        loadedURL = nil
        isLoading = false
    }

    /// Resets the loader to its initial state (clears image, errors, URL).
    func reset() {
        cancel()
        image = nil
        error = nil
    }

    // MARK: - Static helpers

    /// Prefetches image data into the shared URL cache without decoding.
    /// Useful for warming up pages ahead of the reader viewport.
    ///
    /// - Parameter urls: URLs to prefetch.
    static func prefetch(urls: [URL]) {
        for url in urls {
            let request = URLRequest(url: url)

            // Only fetch if not already cached.
            if imageSession.configuration.urlCache?.cachedResponse(for: request) != nil {
                continue
            }

            Task {
                _ = try? await imageSession.data(for: request)
            }
        }
    }
}

// MARK: - Errors

enum ImageLoaderError: LocalizedError {
    case httpError
    case invalidImageData

    var errorDescription: String? {
        switch self {
        case .httpError:
            return "The server returned an error while loading the image."
        case .invalidImageData:
            return "The downloaded data could not be decoded as an image."
        }
    }
}
