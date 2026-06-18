// GalleryCard.swift
// HitomiReader
//
// Card component for gallery grid display.
// Shows thumbnail with gradient title overlay and language badge.

import SwiftUI

struct GalleryCard: View {
    let gallery: Gallery
    
    /// Computed thumbnail URL from the first image hash
    @State private var thumbnailURL: URL? = nil
    
    /// Convert hash to thumbnail path: hash → "c/ab/hash" where ab = last 2 chars, c = 3rd-to-last char
    static func thumbnailPath(hash: String) -> String {
        guard hash.count >= 3 else { return hash }
        let chars = Array(hash)
        let lastTwo = String(chars[(chars.count - 2)...(chars.count - 1)])
        let thirdLast = String(chars[chars.count - 3])
        return "\(thirdLast)/\(lastTwo)/\(hash)"
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // MARK: - Thumbnail Image
                AsyncImageView(
                    url: thumbnailURL,
                    contentMode: .fill,
                    cornerRadius: 0
                )
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
                
                // MARK: - Gradient Overlay
                LinearGradient(
                    colors: [
                        .clear,
                        .clear,
                        Color.black.opacity(0.3),
                        Color.black.opacity(0.85)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                // MARK: - Title & Info
                VStack(alignment: .leading, spacing: 4) {
                    Spacer()
                    
                    Text(displayTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    // Artist name
                    if let artist = gallery.artists?.first?.artist {
                        Text(artist)
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                            .lineLimit(1)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // MARK: - Language Badge
                if let lang = gallery.language {
                    languageBadge(lang)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .padding(8)
                }
                
                // MARK: - Page Count Badge
                if !(gallery.files ?? []).isEmpty {
                    pageCountBadge
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(8)
                }
            }
        }
        .aspectRatio(0.7, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
        .onAppear {
            if let localURL = DownloadManager.shared.getLocalImageURL(for: gallery.id, pageIndex: 0) {
                self.thumbnailURL = localURL
                return
            }
            Task {
                if thumbnailURL == nil, let firstImage = gallery.files?.first {
                    do {
                        try await ImageURLResolver.shared.ensureReady()
                        let resolved = try ImageURLResolver.shared.resolveThumbnailURL(galleryID: gallery.id, image: firstImage)
                        self.thumbnailURL = resolved
                    } catch {
                        print("Failed to resolve thumbnail: \(error)")
                    }
                }
            }
        }
    }
    
    // MARK: - Display Title
    private var displayTitle: String {
        gallery.japaneseTitle ?? gallery.title
    }
    
    // MARK: - Language Badge
    private func languageBadge(_ language: String) -> some View {
        Text(languageAbbreviation(language))
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
            )
    }
    
    // MARK: - Page Count Badge
    private var pageCountBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: "doc.fill")
                .font(.system(size: 8))
            Text("\(gallery.files?.count ?? 0)")
                .font(.system(size: 9, weight: .bold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.6))
        )
    }
    
    // MARK: - Language Abbreviation
    private func languageAbbreviation(_ language: String) -> String {
        switch language.lowercased() {
        case "english":    return "EN"
        case "japanese":   return "JP"
        case "korean":     return "KR"
        case "chinese":    return "CN"
        case "vietnamese": return "VN"
        default:           return language.prefix(2).uppercased()
        }
    }
}

#Preview {
    let sampleGallery = Gallery(
        id: 12345,
        title: "Sample Gallery Title That Is Quite Long",
        japaneseTitle: "サンプルギャラリー",
        artists: [Gallery.Artist(artist: "Artist Name", url: "/artist/test")],
        groups: [],
        parodys: [],
        tags: [],
        characters: [],
        language: "japanese",
        languageLocalname: "日本語",
        type: "manga",
        date: "2024-01-01",
        files: [GalleryImage(name: "001.jpg", hash: "abc123def456", width: 1200, height: 1700, haswebp: 1, hasavif: 0, hasjxl: 0)]
    )
    
    GalleryCard(gallery: sampleGallery)
        .frame(width: 170, height: 240)
        .padding()
        .background(Color(hex: "0D0D0D"))
        .preferredColorScheme(.dark)
}

/// Custom button style that scales down slightly when pressed, providing premium spring tactile feedback.
struct PressedScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

