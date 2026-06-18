// Tag.swift
// HitomiReader
//
// Represents a single tag from a gallery's metadata.
// hitomi.la tags may carry a gender marker: the JSON object
// may contain a "female" or "male" key (with value "") indicating
// the tag belongs to that gender category.
//
// Example JSON:
//   { "tag": "schoolgirl", "url": "/tag/female:schoolgirl-all.html", "female": "" }
//   { "tag": "glasses",    "url": "/tag/glasses-all.html" }

import Foundation

struct Tag: Codable, Hashable, Identifiable {

    // MARK: - Stored properties

    let tag: String
    let url: String
    let gender: Gender?     // nil when the tag has no gender prefix
    var count: Int? = nil   // Optional count of items returned by search index

    // MARK: - Gender enum

    enum Gender: String, Codable, Hashable {
        case female
        case male
    }

    // MARK: - Identifiable

    var id: String { displayName }

    // MARK: - Computed

    /// Display name including the gender prefix when applicable.
    /// e.g. "female:schoolgirl", "male:yaoi", "glasses"
    var displayName: String {
        if let gender = gender {
            return "\(gender.rawValue):\(tag)"
        }
        return tag
    }

    /// The tag type path component used in .nozomi URLs.
    /// Gender-prefixed tags use "female" / "male" as the tag type
    /// under the `n/` path. Non-gendered tags use "tag".
    var nozomiTagType: String {
        if let gender = gender {
            return gender.rawValue
        }
        return "tag"
    }

    /// The value used in .nozomi file paths, e.g. "schoolgirl" or "glasses".
    var nozomiTagValue: String {
        tag
    }

    // MARK: - Custom Decoding

    enum CodingKeys: String, CodingKey {
        case tag
        case url
        case female
        case male
    }

    init(tag: String, url: String, gender: Gender?, count: Int? = nil) {
        self.tag = tag
        self.url = url
        self.gender = gender
        self.count = count
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tag = try container.decode(String.self, forKey: .tag)
        url = try container.decode(String.self, forKey: .url)

        // Determine gender by checking which key contains a non-empty string.
        let femaleVal = try? container.decodeIfPresent(String.self, forKey: .female)
        let maleVal = try? container.decodeIfPresent(String.self, forKey: .male)

        if let maleVal = maleVal, !maleVal.isEmpty {
            gender = .male
        } else if let femaleVal = femaleVal, !femaleVal.isEmpty {
            gender = .female
        } else {
            gender = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(tag, forKey: .tag)
        try container.encode(url, forKey: .url)
        if gender == .female {
            try container.encode("", forKey: .female)
        } else if gender == .male {
            try container.encode("", forKey: .male)
        }
    }
}
