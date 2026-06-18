// NozomiParser.swift
// HitomiReader
//
// Parses hitomi.la's .nozomi binary format.
// .nozomi files are arrays of big-endian 32-bit unsigned integers,
// each representing a gallery ID. Results are ordered from newest to oldest.
//
// Pagination is done via HTTP Range headers:
//   Range: bytes={start}-{end}
// where each gallery ID occupies 4 bytes.

import Foundation

struct NozomiParser {

    // MARK: - Constants

    /// Bytes per gallery ID entry in the .nozomi format.
    static let bytesPerID = 4

    /// Number of gallery IDs to fetch per page.
    static let defaultPageSize = 25

    // MARK: - Binary Parsing

    /// Parses raw .nozomi data into an array of gallery IDs.
    ///
    /// - Parameter data: Raw bytes from a .nozomi response.
    /// - Returns: Array of gallery IDs in the order they appear.
    static func parseNozomiData(_ data: Data) -> [Int] {
        let count = data.count / bytesPerID
        guard count > 0 else { return [] }

        var ids = [Int]()
        ids.reserveCapacity(count)

        data.withUnsafeBytes { raw in
            let buffer = raw.bindMemory(to: UInt32.self)
            for i in 0..<count {
                // .nozomi uses big-endian byte order.
                let bigEndianValue = buffer[i]
                let galleryID = Int(UInt32(bigEndian: bigEndianValue))
                ids.append(galleryID)
            }
        }

        return ids
    }

    // MARK: - URL Construction

    /// Base URL for all .nozomi endpoints.
    private static let baseURL = "https://ltn.gold-usergeneratedcontent.net"

    /// Builds the .nozomi URL for a language-specific index.
    ///
    /// - Parameter language: Language string (e.g. "english", "japanese").
    ///                       Pass `nil` or `"all"` for the global index.
    /// - Returns: Full URL string.
    static func indexURL(language: String?) -> String {
        if let lang = language, !lang.isEmpty, lang.lowercased() != "all" {
            return "\(baseURL)/index-\(lang.lowercased()).nozomi"
        }
        return "\(baseURL)/index-all.nozomi"
    }

    /// Builds the .nozomi URL for a tag-filtered list.
    ///
    /// - Parameters:
    ///   - tagType: The tag type path (e.g. "female", "male", "tag", "artist", "group").
    ///   - tagValue: The tag name (e.g. "schoolgirl", "glasses").
    ///   - language: Optional language filter.
    /// - Returns: Full URL string.
    static func tagURL(tagType: String, tagValue: String, language: String? = nil) -> String {
        let lang = (language?.lowercased() == nil || language?.lowercased() == "all" || language?.isEmpty == true) ? "all" : language!.lowercased()
        
        let area: String
        let tagPrefix: String
        
        switch tagType.lowercased() {
        case "male", "female":
            area = "tag"
            tagPrefix = "\(tagType.lowercased()):"
        default:
            area = tagType.lowercased()
            tagPrefix = ""
        }
        
        let encodedTagValue = tagValue.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? tagValue
        return "\(baseURL)/n/\(area)/\(tagPrefix)\(encodedTagValue)-\(lang).nozomi"
    }

    // MARK: - Range Header

    /// Computes the HTTP Range header value for the given page.
    ///
    /// - Parameters:
    ///   - page: Zero-indexed page number.
    ///   - pageSize: Number of IDs per page (default 25).
    /// - Returns: A tuple of (rangeHeaderValue, byteStart, byteEnd).
    static func rangeHeader(page: Int, pageSize: Int = defaultPageSize) -> (header: String, start: Int, end: Int) {
        let start = page * pageSize * bytesPerID
        let end   = start + (pageSize * bytesPerID) - 1
        return ("bytes=\(start)-\(end)", start, end)
    }

    /// Estimates the total number of gallery IDs from a Content-Range header.
    ///
    /// - Parameter contentRange: The Content-Range header value,
    ///   e.g. "bytes 0-99/123456".
    /// - Returns: Total number of gallery IDs, or nil if parsing fails.
    static func totalCount(fromContentRange contentRange: String?) -> Int? {
        // Format: "bytes 0-99/12345"
        guard let range = contentRange,
              let slashIndex = range.lastIndex(of: "/"),
              let total = Int(range[range.index(after: slashIndex)...])
        else {
            return nil
        }
        return total / bytesPerID
    }
}
