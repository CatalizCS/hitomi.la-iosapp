// GalleryImage.swift
// HitomiReader
//
// Represents one image file in a gallery's `files` array.
// The `hash` field is the critical piece used by ImageURLResolver
// to compute the correct CDN subdomain and path.

import Foundation

struct GalleryImage: Codable, Identifiable, Hashable {
    let name: String       // Original filename, e.g. "001.jpg"
    let hash: String       // Hex hash string used for URL resolution
    let width: Int
    let height: Int
    let haswebp: Int       // 0 or 1
    let hasavif: Int       // 0 or 1
    let hasjxl: Int?       // 0 or 1 — may be absent in older entries

    // MARK: - Identifiable

    var id: String { hash }

    // MARK: - Convenience

    /// The file extension extracted from the original filename.
    var fileExtension: String {
        (name as NSString).pathExtension.lowercased()
    }

    /// Aspect ratio (width / height), useful for layout calculations.
    var aspectRatio: CGFloat {
        guard height > 0 else { return 1.0 }
        return CGFloat(width) / CGFloat(height)
    }

    /// Whether a WebP variant is available on the CDN.
    var webpAvailable: Bool { haswebp == 1 }

    /// Whether an AVIF variant is available on the CDN.
    var avifAvailable: Bool { hasavif == 1 }

    /// Whether a JPEG-XL variant is available on the CDN.
    var jxlAvailable: Bool { hasjxl == 1 }
}
