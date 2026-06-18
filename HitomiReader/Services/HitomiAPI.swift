// HitomiAPI.swift
// HitomiReader
//
// Central API client for hitomi.la.
//
// Gallery discovery flow:
//   1. Fetch a page of gallery IDs from a .nozomi endpoint (binary).
//   2. For each ID, fetch the full gallery metadata from /galleries/{id}.js.
//
// All HTTP requests include `Referer: https://hitomi.la/` as required.

import Foundation

@MainActor
final class HitomiAPI: ObservableObject {

    // MARK: - Singleton

    static let shared = HitomiAPI()

    // MARK: - Published state

    @Published private(set) var isLoading = false

    // MARK: - Private

    /// Shared URLSession with a custom configuration.
    private let session: URLSession

    /// JS prefix that wraps the gallery JSON payload.
    private static let galleryJSPrefix = "var galleryinfo = "

    // MARK: - Init

    private init() {
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = [
            "Referer": "https://hitomi.la/",
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1"
        ]
        // 50 MB memory cache, 200 MB disk cache.
        config.urlCache = URLCache(
            memoryCapacity: 50 * 1024 * 1024,
            diskCapacity: 200 * 1024 * 1024
        )
        self.session = URLSession(configuration: config)
    }

    // MARK: - Gallery List (Nozomi)

    /// Fetches a page of gallery IDs from a .nozomi index.
    ///
    /// - Parameters:
    ///   - language: Language filter (e.g. "english"). Pass nil for all.
    ///   - page: Zero-indexed page number.
    ///   - pageSize: Number of IDs per page.
    /// - Returns: A tuple of (galleryIDs, estimatedTotalCount).
    func fetchGalleryIDs(
        language: String?,
        page: Int,
        pageSize: Int = NozomiParser.defaultPageSize
    ) async throws -> (ids: [Int], totalCount: Int?) {
        let urlString = NozomiParser.indexURL(language: language)
        guard let url = URL(string: urlString) else {
            throw HitomiAPIError.invalidURL(urlString)
        }

        let range = NozomiParser.rangeHeader(page: page, pageSize: pageSize)

        var request = URLRequest(url: url)
        request.setValue(range.header, forHTTPHeaderField: "Range")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw HitomiAPIError.httpError(statusCode: statusCode, galleryID: -1)
        }

        // Parse the binary nozomi data.
        let ids = NozomiParser.parseNozomiData(data)

        // Attempt to extract total count from Content-Range header.
        let contentRange = httpResponse.value(forHTTPHeaderField: "Content-Range")
        let totalCount = NozomiParser.totalCount(fromContentRange: contentRange)

        return (ids, totalCount)
    }

    /// Fetches a page of gallery IDs filtered by tag.
    ///
    /// - Parameters:
    ///   - tag: The Tag to filter by.
    ///   - language: Optional language filter.
    ///   - page: Zero-indexed page number.
    ///   - pageSize: Number of IDs per page.
    /// - Returns: A tuple of (galleryIDs, estimatedTotalCount).
    func fetchGalleryIDs(
        tag: Tag,
        language: String?,
        page: Int,
        pageSize: Int = NozomiParser.defaultPageSize
    ) async throws -> (ids: [Int], totalCount: Int?) {
        let urlString = NozomiParser.tagURL(
            tagType: tag.nozomiTagType,
            tagValue: tag.nozomiTagValue,
            language: language
        )
        guard let url = URL(string: urlString) else {
            throw HitomiAPIError.invalidURL(urlString)
        }

        let range = NozomiParser.rangeHeader(page: page, pageSize: pageSize)

        var request = URLRequest(url: url)
        request.setValue(range.header, forHTTPHeaderField: "Range")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw HitomiAPIError.httpError(statusCode: statusCode, galleryID: -1)
        }

        let ids = NozomiParser.parseNozomiData(data)

        let contentRange = httpResponse.value(forHTTPHeaderField: "Content-Range")
        let totalCount = NozomiParser.totalCount(fromContentRange: contentRange)

        return (ids, totalCount)
    }

    // MARK: - Gallery Detail

    /// Fetches full gallery metadata for a single gallery ID.
    ///
    /// The endpoint returns JavaScript: `var galleryinfo = { ... }`
    /// We strip the prefix and parse the remainder as JSON.
    ///
    /// - Parameter id: The gallery's numeric ID.
    /// - Returns: A fully-decoded `Gallery` instance.
    func fetchGallery(id: Int) async throws -> Gallery {
        let urlString = "https://ltn.gold-usergeneratedcontent.net/galleries/\(id).js"
        guard let url = URL(string: urlString) else {
            throw HitomiAPIError.invalidURL(urlString)
        }

        let request = URLRequest(url: url)
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw HitomiAPIError.httpError(statusCode: statusCode, galleryID: id)
        }

        guard var jsonString = String(data: data, encoding: .utf8) else {
            throw HitomiAPIError.invalidResponse(galleryID: id)
        }

        // Strip the JS variable assignment prefix.
        if jsonString.hasPrefix(Self.galleryJSPrefix) {
            jsonString = String(jsonString.dropFirst(Self.galleryJSPrefix.count))
        }

        guard let jsonData = jsonString.data(using: .utf8) else {
            throw HitomiAPIError.invalidResponse(galleryID: id)
        }

        let decoder = JSONDecoder()
        do {
            let gallery = try decoder.decode(Gallery.self, from: jsonData)
            return gallery
        } catch {
            throw HitomiAPIError.decodingFailed(galleryID: id, underlying: error)
        }
    }

    // MARK: - Batch Fetch

    /// Fetches full gallery metadata for multiple IDs concurrently.
    ///
    /// Failed individual fetches are silently skipped — partial results
    /// are returned rather than failing the entire batch.
    ///
    /// - Parameter ids: Array of gallery IDs to fetch.
    /// - Returns: Successfully decoded galleries (order not guaranteed).
    func fetchGalleries(ids: [Int]) async -> [Gallery] {
        isLoading = true
        defer { isLoading = false }

        return await withTaskGroup(of: Gallery?.self) { group in
            for id in ids {
                group.addTask { [weak self] in
                    try? await self?.fetchGallery(id: id)
                }
            }

            var galleries = [Gallery]()
            galleries.reserveCapacity(ids.count)

            for await gallery in group {
                if let gallery = gallery {
                    galleries.append(gallery)
                }
            }

            // Re-sort to match the original .nozomi ordering.
            let idOrder = Dictionary(uniqueKeysWithValues: ids.enumerated().map { ($1, $0) })
            galleries.sort { (idOrder[$0.id] ?? Int.max) < (idOrder[$1.id] ?? Int.max) }

            return galleries
        }
    }

    // MARK: - Convenience: Full Page Fetch

    /// Fetches a complete page of galleries (IDs + metadata) in one call.
    ///
    /// - Parameters:
    ///   - language: Language filter.
    ///   - page: Zero-indexed page number.
    ///   - pageSize: Items per page.
    /// - Returns: A tuple of (galleries, estimatedTotalCount).
    func fetchGalleryPage(
        language: String?,
        page: Int,
        pageSize: Int = NozomiParser.defaultPageSize
    ) async throws -> (galleries: [Gallery], totalCount: Int?) {
        let (ids, totalCount) = try await fetchGalleryIDs(
            language: language,
            page: page,
            pageSize: pageSize
        )

        guard !ids.isEmpty else {
            return ([], totalCount)
        }

        let galleries = await fetchGalleries(ids: ids)
        return (galleries, totalCount)
    }

    // MARK: - View Compatibility Wrappers

    /// Fetches gallery IDs for BrowseView.
    func fetchGalleryIDs(page: Int, perPage: Int, language: String? = nil) async throws -> [Int] {
        let (ids, _) = try await fetchGalleryIDs(language: language, page: page, pageSize: perPage)
        return ids
    }

    /// Fetches a gallery's metadata. Alias of `fetchGallery`.
    func fetchGalleryInfo(id: Int) async throws -> Gallery {
        try await fetchGallery(id: id)
    }

    /// Fetches gallery IDs by tag for SearchView.
    func fetchGalleryIDsByTag(type: String, name: String, page: Int, perPage: Int) async throws -> [Int] {
        let gender: Tag.Gender? = Tag.Gender(rawValue: type)
        // Match the url structure used in hitomi
        let tagUrl = "/tag/\(type == "tag" ? "" : type + ":")\(name)-all.html"
        let tag = Tag(tag: name, url: tagUrl, gender: gender)
        let (ids, _) = try await fetchGalleryIDs(tag: tag, language: nil, page: page, pageSize: perPage)
        return ids
    }

    /// Resolves an image URL using the singleton ImageURLResolver.
    func getImageURL(image: GalleryImage, galleryID: Int) async throws -> URL {
        try await ImageURLResolver.shared.ensureReady()
        return try ImageURLResolver.shared.resolveImageURL(galleryID: galleryID, image: image)
    }
}

// MARK: - Errors

enum HitomiAPIError: LocalizedError {
    case invalidURL(String)
    case httpError(statusCode: Int, galleryID: Int)
    case invalidResponse(galleryID: Int)
    case decodingFailed(galleryID: Int, underlying: Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .httpError(let code, let id):
            return "HTTP \(code) when fetching gallery \(id)."
        case .invalidResponse(let id):
            return "Invalid response body for gallery \(id)."
        case .decodingFailed(let id, let underlying):
            return "Failed to decode gallery \(id): \(underlying.localizedDescription)"
        }
    }
}
