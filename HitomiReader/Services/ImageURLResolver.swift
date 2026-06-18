// ImageURLResolver.swift
// HitomiReader
//
// Resolves the full CDN URL for a GalleryImage by:
//   1. Fetching the latest gg.js from hitomi.la (contains subdomain logic)
//   2. Injecting the common.js helper functions into a JSContext
//   3. Calling url_from_hash() to produce the final URL
//
// gg.js changes frequently — the resolver caches it for a short TTL
// and re-fetches automatically when it expires.

import Foundation
import JavaScriptCore

@MainActor
final class ImageURLResolver: ObservableObject {

    // MARK: - Singleton

    static let shared = ImageURLResolver()

    // MARK: - State

    @Published private(set) var isReady = false

    /// The cached JavaScript context with gg.js + common.js loaded.
    private var jsContext: JSContext?

    /// Timestamp of the last successful gg.js fetch.
    private var lastFetchDate: Date?

    /// How long to cache gg.js before re-fetching (10 minutes).
    private let cacheTTL: TimeInterval = 600

    // MARK: - Constants

    private let ggJSURL = URL(string: "https://ltn.gold-usergeneratedcontent.net/gg.js")!

    /// The common.js helper functions that hitomi.la's frontend uses.
    /// These are stable and rarely change; we embed them directly.
    private let commonJSSource = """
    const domain2 = 'gold-usergeneratedcontent.net';

    function subdomain_from_url(url, base, dir) {
        var retval = '';
        if (!base) {
            if (dir === 'webp') {
                retval = 'w';
            } else if (dir === 'avif') {
                retval = 'a';
            }
        }

        var b = 16;

        var r = /\\/[0-9a-f]{61}([0-9a-f]{2})([0-9a-f])/;
        var m = r.exec(url);
        if (!m) {
            return retval;
        }

        var g = parseInt(m[2]+m[1], b);
        if (!isNaN(g)) {
            if (base) {
                retval = String.fromCharCode(97 + gg.m(g)) + base;
            } else {
                retval = retval + (1+gg.m(g));
            }
        }

        return retval;
    }

    function url_from_url(url, base, dir) {
        return url.replace(/\\/\\/..?\\.(?:gold-usergeneratedcontent\\.net|hitomi\\.la)\\//, '//'+subdomain_from_url(url, base, dir)+'.'+domain2+'/');
    }

    function full_path_from_hash(hash) {
        return gg.b+gg.s(hash)+'/'+hash;
    }

    function real_full_path_from_hash(hash) {
        return hash.replace(/^.*(..)(.)$/, '$2/$1/'+hash);
    }

    function url_from_hash(galleryid, image, dir, ext) {
        ext = ext || dir || image.name.split('.').pop();
        if (dir === 'webp' || dir === 'avif') {
            dir = '';
        } else {
            dir += '/';
        }

        return 'https://a.'+domain2+'/'+dir+full_path_from_hash(image.hash)+'.'+ext;
    }

    function url_from_url_from_hash(galleryid, image, dir, ext, base) {
        if ('tn' === base) {
            return url_from_url('https://a.'+domain2+'/'+dir+'/'+real_full_path_from_hash(image.hash)+'.'+ext, base);
        }
        return url_from_url(url_from_hash(galleryid, image, dir, ext), base, dir);
    }
    """

    // MARK: - Init

    private init() {}

    // MARK: - Public API

    /// Ensures gg.js is loaded and the JS context is ready.
    /// Call this before resolving any URLs. Safe to call multiple times.
    func ensureReady() async throws {
        if let lastFetch = lastFetchDate,
           Date().timeIntervalSince(lastFetch) < cacheTTL,
           jsContext != nil {
            return // Still fresh
        }
        try await fetchAndPrepare()
    }

    /// Resolves the full CDN URL for the original-quality image.
    ///
    /// - Parameters:
    ///   - galleryID: The gallery's numeric ID.
    ///   - image: The image file descriptor from the gallery.
    /// - Returns: The fully-qualified HTTPS URL string.
    func resolveImageURL(galleryID: Int, image: GalleryImage) throws -> URL {
        guard let ctx = jsContext else {
            throw ImageURLResolverError.notReady
        }

        let hasWebpValue = image.haswebp ?? 1
        let hasAvifValue = image.hasavif ?? 0

        // Build a JS object literal for the image parameter.
        let imageJSON = """
        ({ "name": "\(image.name)", "hash": "\(image.hash)", "haswebp": \(hasWebpValue), "hasavif": \(hasAvifValue) })
        """

        // Use WebP quality for loading pages since hitomi.la no longer hosts original JPG/PNG formats.
        let script = "url_from_url_from_hash(\(galleryID), \(imageJSON), 'webp', 'webp')"

        guard let result = ctx.evaluateScript(script),
              let urlString = result.toString(),
              !urlString.isEmpty,
              urlString != "undefined" else {
            throw ImageURLResolverError.evaluationFailed
        }

        guard let url = URL(string: urlString) else {
            throw ImageURLResolverError.invalidURL(urlString)
        }

        return url
    }

    /// Resolves a thumbnail URL for the given image.
    /// Thumbnails use the 'webpbigtn' directory with webp extension on hitomi.
    func resolveThumbnailURL(galleryID: Int, image: GalleryImage) throws -> URL {
        guard let ctx = jsContext else {
            throw ImageURLResolverError.notReady
        }

        let hasWebpValue = image.haswebp ?? 1
        let hasAvifValue = image.hasavif ?? 0

        let imageJSON = """
        ({ "name": "\(image.name)", "hash": "\(image.hash)", "haswebp": \(hasWebpValue), "hasavif": \(hasAvifValue) })
        """

        let script = "url_from_url_from_hash(\(galleryID), \(imageJSON), 'webpbigtn', 'webp', 'tn')"

        guard let result = ctx.evaluateScript(script),
              let urlString = result.toString(),
              !urlString.isEmpty,
              urlString != "undefined" else {
            throw ImageURLResolverError.evaluationFailed
        }

        guard let url = URL(string: urlString) else {
            throw ImageURLResolverError.invalidURL(urlString)
        }

        return url
    }

    /// Force-refreshes gg.js from the server.
    func refresh() async throws {
        try await fetchAndPrepare()
    }

    // MARK: - Private

    private func fetchAndPrepare() async throws {
        var request = URLRequest(url: ggJSURL)
        request.setValue("https://hitomi.la/", forHTTPHeaderField: "Referer")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ImageURLResolverError.fetchFailed
        }

        guard let ggSource = String(data: data, encoding: .utf8) else {
            throw ImageURLResolverError.invalidGGJS
        }

        // Create a fresh JavaScript context.
        guard let ctx = JSContext() else {
            throw ImageURLResolverError.jsContextCreationFailed
        }

        // Set up error handling on the JS context.
        ctx.exceptionHandler = { _, exception in
            if let exc = exception {
                print("[ImageURLResolver] JS Exception: \(exc)")
            }
        }

        // Evaluate gg.js first.
        // Prepend 'var gg;' because gg.js runs in strict mode and assumes gg is already declared.
        let ggScript = "var gg; " + ggSource
        ctx.evaluateScript(ggScript)

        // Then evaluate our common.js helpers that depend on gg().
        ctx.evaluateScript(commonJSSource)

        // Verify the context is functional.
        let test = ctx.evaluateScript("typeof url_from_url_from_hash")
        guard let testResult = test?.toString(), testResult == "function" else {
            throw ImageURLResolverError.invalidGGJS
        }

        self.jsContext = ctx
        self.lastFetchDate = Date()
        self.isReady = true
    }
}

// MARK: - Errors

enum ImageURLResolverError: LocalizedError {
    case notReady
    case fetchFailed
    case invalidGGJS
    case jsContextCreationFailed
    case evaluationFailed
    case invalidURL(String)

    var errorDescription: String? {
        switch self {
        case .notReady:
            return "ImageURLResolver has not been initialized. Call ensureReady() first."
        case .fetchFailed:
            return "Failed to fetch gg.js from hitomi.la."
        case .invalidGGJS:
            return "The gg.js content is invalid or could not be parsed."
        case .jsContextCreationFailed:
            return "Failed to create a JavaScriptCore context."
        case .evaluationFailed:
            return "JavaScript evaluation returned an unexpected result."
        case .invalidURL(let url):
            return "Resolved URL is malformed: \(url)"
        }
    }
}
