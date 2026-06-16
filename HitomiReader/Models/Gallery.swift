// Gallery.swift
// HitomiReader
//
// Main data model for a hitomi.la gallery entry.
// Decoded from the JSON payload at https://ltn.hitomi.la/galleries/{id}.js
// after stripping the "var galleryinfo = " prefix.

import Foundation

// MARK: - Gallery

struct Gallery: Codable, Identifiable, Hashable {
    let id: Int
    let title: String
    let japaneseTitle: String?
    let language: String?
    let languageLocalname: String?
    let languageURL: String?
    let type: String?          // manga, doujinshi, gamecg, artistcg, anime
    let date: String?          // e.g. "2024-01-15 12:30:00-05"
    let tags: [Tag]?
    let artists: [Artist]?
    let groups: [Group]?
    let characters: [Character]?
    let parodys: [Parody]?
    let files: [GalleryImage]?

    // MARK: Coding Keys — map snake_case JSON keys to camelCase

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case japaneseTitle   = "japanese_title"
        case language
        case languageLocalname = "language_localname"
        case languageURL     = "language_url"
        case type
        case date
        case tags
        case artists
        case groups
        case characters
        case parodys
        case files
    }

    // MARK: - Convenience

    /// Best available title — prefers Japanese title when present.
    var displayTitle: String {
        japaneseTitle ?? title
    }

    /// Total page count based on the `files` array.
    var pageCount: Int {
        files?.count ?? 0
    }
}

// MARK: - Nested metadata types

extension Gallery {

    struct Artist: Codable, Hashable, Identifiable {
        let artist: String
        let url: String

        var id: String { artist }
    }

    struct Group: Codable, Hashable, Identifiable {
        let group: String
        let url: String

        var id: String { group }
    }

    struct Character: Codable, Hashable, Identifiable {
        let character: String
        let url: String

        var id: String { character }
    }

    struct Parody: Codable, Hashable, Identifiable {
        let parody: String
        let url: String

        var id: String { parody }
    }
}

// MARK: - Convenience Initializer

extension Gallery {
    init(
        id: Int,
        title: String,
        japaneseTitle: String? = nil,
        artists: [Artist]? = nil,
        groups: [Group]? = nil,
        parodys: [Parody]? = nil,
        tags: [Tag]? = nil,
        characters: [Character]? = nil,
        language: String? = nil,
        languageLocalname: String? = nil,
        languageURL: String? = nil,
        type: String? = nil,
        date: String? = nil,
        files: [GalleryImage]? = nil
    ) {
        self.id = id
        self.title = title
        self.japaneseTitle = japaneseTitle
        self.language = language
        self.languageLocalname = languageLocalname
        self.languageURL = languageURL
        self.type = type
        self.date = date
        self.tags = tags
        self.artists = artists
        self.groups = groups
        self.characters = characters
        self.parodys = parodys
        self.files = files
    }
}
