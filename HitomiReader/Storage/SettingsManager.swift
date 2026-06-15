// SettingsManager.swift
// HitomiReader
//
// Manages user preferences persisted to UserDefaults.
// Observable for SwiftUI data flow.

import Foundation

// MARK: - Reader Direction

enum ReaderDirection: String, Codable, CaseIterable, Identifiable {
    case rtl       = "rtl"          // Right-to-left (manga style)
    case ltr       = "ltr"          // Left-to-right (western style)
    case vertical  = "vertical"     // Vertical scroll

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .rtl:      return "Right to Left (Manga)"
        case .ltr:      return "Left to Right"
        case .vertical: return "Vertical Scroll"
        }
    }
}

// MARK: - Settings Manager

@MainActor
final class SettingsManager: ObservableObject {

    // MARK: - Singleton

    static let shared = SettingsManager()

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let preferredLanguage     = "settings.preferredLanguage"
        static let hasCompletedOnboarding = "settings.hasCompletedOnboarding"
        static let readerDirection       = "settings.readerDirection"
        static let itemsPerPage          = "settings.itemsPerPage"
    }

    // MARK: - Published Properties

    /// The user's preferred content language (e.g. "english", "japanese").
    /// Set during onboarding. `nil` means "all languages".
    @Published var preferredLanguage: String? {
        didSet {
            if let lang = preferredLanguage {
                defaults.set(lang, forKey: Keys.preferredLanguage)
            } else {
                defaults.removeObject(forKey: Keys.preferredLanguage)
            }
        }
    }

    /// Whether the user has completed the initial onboarding flow.
    @Published var hasCompletedOnboarding: Bool {
        didSet {
            defaults.set(hasCompletedOnboarding, forKey: Keys.hasCompletedOnboarding)
        }
    }

    /// The preferred reader direction. Defaults to RTL (manga-style).
    @Published var readerDirection: ReaderDirection {
        didSet {
            defaults.set(readerDirection.rawValue, forKey: Keys.readerDirection)
        }
    }

    /// Number of items to fetch per page in gallery lists.
    @Published var itemsPerPage: Int {
        didSet {
            defaults.set(itemsPerPage, forKey: Keys.itemsPerPage)
        }
    }

    // MARK: - Private

    private let defaults = UserDefaults.standard

    // MARK: - Init

    private init() {
        // Load persisted values, falling back to sensible defaults.
        self.preferredLanguage = defaults.string(forKey: Keys.preferredLanguage)
        self.hasCompletedOnboarding = defaults.bool(forKey: Keys.hasCompletedOnboarding)
        self.itemsPerPage = defaults.integer(forKey: Keys.itemsPerPage)

        if self.itemsPerPage == 0 {
            self.itemsPerPage = NozomiParser.defaultPageSize
        }

        if let dirRaw = defaults.string(forKey: Keys.readerDirection),
           let dir = ReaderDirection(rawValue: dirRaw) {
            self.readerDirection = dir
        } else {
            // Default: Right-to-left (manga style).
            self.readerDirection = .rtl
        }
    }

    // MARK: - Convenience

    /// Available language options for the onboarding picker.
    static let availableLanguages: [(code: String?, displayName: String)] = [
        (nil,          "All Languages"),
        ("english",    "English"),
        ("japanese",   "日本語 (Japanese)"),
        ("korean",     "한국어 (Korean)"),
        ("chinese",    "中文 (Chinese)"),
        ("vietnamese", "Tiếng Việt (Vietnamese)"),
    ]

    /// Resets all settings to defaults (useful for testing / sign-out).
    func resetToDefaults() {
        preferredLanguage = nil
        hasCompletedOnboarding = false
        readerDirection = .rtl
        itemsPerPage = NozomiParser.defaultPageSize
    }
}
