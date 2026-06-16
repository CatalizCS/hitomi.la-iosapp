// GalleryDetailView.swift
// HitomiReader
//
// Detailed gallery view showing cover image, metadata, tags, and read button.
// Supports favoriting tags and continuing from last read page.

import SwiftUI

struct GalleryDetailView: View {
    let gallery: Gallery
    
    @EnvironmentObject var history: HistoryManager
    @EnvironmentObject var favoriteTags: FavoriteTagsManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var showReader = false
    @State private var startPage = 0
    @State private var coverImageAppeared = false
    
    // MARK: - Computed Properties
    
    private var displayTitle: String {
        gallery.japaneseTitle ?? gallery.title
    }
    
    private var secondaryTitle: String? {
        guard gallery.japaneseTitle != nil else { return nil }
        return gallery.title
    }
    
    private var coverURL: URL? {
        guard let firstImage = gallery.files?.first else { return nil }
        let path = GalleryCard.thumbnailPath(hash: firstImage.hash)
        return URL(string: "https://tn.hitomi.la/bigtn/\(path).jpg")
    }
    
    /// Check reading history for this gallery
    private var historyEntry: HistoryEntry? {
        history.entries.first(where: { $0.galleryID == gallery.id })
    }
    
    var body: some View {
        ZStack {
            Color(hex: "0D0D0D").ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    // MARK: - Cover Image
                    coverSection
                    
                    // MARK: - Info Content
                    VStack(alignment: .leading, spacing: 20) {
                        titleSection
                        metadataBadges
                        artistsSection
                        tagsSection
                        readButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showReader) {
            ReaderView(gallery: gallery, startPage: startPage)
        }
    }
    
    // MARK: - Cover Section
    private var coverSection: some View {
        ZStack(alignment: .bottom) {
            AsyncImageView(
                url: coverURL,
                contentMode: .fit,
                cornerRadius: 0
            )
            .frame(maxWidth: .infinity)
            .frame(height: 420)
            .clipped()
            .opacity(coverImageAppeared ? 1 : 0)
            .onAppear {
                withAnimation(.easeOut(duration: 0.4)) {
                    coverImageAppeared = true
                }
            }
            
            // Bottom gradient fade
            LinearGradient(
                colors: [.clear, Color(hex: "0D0D0D")],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 100)
        }
    }
    
    // MARK: - Title Section
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(displayTitle)
                .font(.title2.bold())
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
            
            if let secondary = secondaryTitle {
                Text(secondary)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.5))
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Text("ID: \(gallery.id)")
                .font(.caption)
                .foregroundColor(.white.opacity(0.3))
        }
    }
    
    // MARK: - Metadata Badges
    private var metadataBadges: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                // Type badge
                if let type = gallery.type {
                    metadataBadge(
                        icon: "doc.text.fill",
                        text: type.capitalized,
                        color: Color(hex: "8B5CF6")
                    )
                }
                
                // Language badge
                if let lang = gallery.languageLocalname ?? gallery.language {
                    metadataBadge(
                        icon: "globe",
                        text: lang,
                        color: Color(hex: "EAB308")
                    )
                }
                
                // Page count badge
                metadataBadge(
                    icon: "doc.fill",
                    text: "\(gallery.files?.count ?? 0) pages",
                    color: Color(hex: "14B8A6")
                )
                
                // Date badge
                if let date = gallery.date {
                    metadataBadge(
                        icon: "calendar",
                        text: String(date.prefix(10)),
                        color: Color(hex: "6B7280")
                    )
                }
            }
        }
    }
    
    private func metadataBadge(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(.caption.weight(.medium))
        }
        .foregroundColor(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.12))
        )
    }
    
    // MARK: - Artists Section
    private var artistsSection: some View {
        let artists = gallery.artists ?? []
        let groups = gallery.groups ?? []
        let parodys = gallery.parodys ?? []
        let characters = gallery.characters ?? []
        
        return Group {
            if !artists.isEmpty || !groups.isEmpty || !parodys.isEmpty || !characters.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    if !artists.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            sectionLabel("Artists")
                            FlowLayout(spacing: 8) {
                                ForEach(artists, id: \.artist) { artist in
                                    TagChip(name: artist.artist, type: .artist) {
                                        // Could navigate to artist search
                                    }
                                }
                            }
                        }
                    }
                    
                    if !groups.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            sectionLabel("Groups")
                            FlowLayout(spacing: 8) {
                                ForEach(groups, id: \.group) { group in
                                    TagChip(name: group.group, type: .group)
                                }
                            }
                        }
                    }
                    
                    if !parodys.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            sectionLabel("Series")
                            FlowLayout(spacing: 8) {
                                ForEach(parodys, id: \.parody) { parody in
                                    TagChip(name: parody.parody, type: .series)
                                }
                            }
                        }
                    }
                    
                    if !characters.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            sectionLabel("Characters")
                            FlowLayout(spacing: 8) {
                                ForEach(characters, id: \.character) { char in
                                    TagChip(name: char.character, type: .character)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Tags Section
    private var tagsSection: some View {
        let tags = gallery.tags ?? []
        return Group {
            if !tags.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        sectionLabel("Tags")
                        Spacer()
                        
                        // Favorite all tags button
                        Button {
                            favoriteAllTags()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "heart.fill")
                                    .font(.caption2)
                                Text("Save All")
                                    .font(.caption2.weight(.medium))
                            }
                            .foregroundColor(Color(hex: "FF2D78"))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(Color(hex: "FF2D78").opacity(0.12))
                            )
                        }
                    }
                    
                    FlowLayout(spacing: 8) {
                        ForEach(tags, id: \.tag) { tag in
                            tagChipWithFavorite(tag)
                        }
                    }
                }
            }
        }
    }
    
    private func tagChipWithFavorite(_ tag: Tag) -> some View {
        let isFav = favoriteTags.isFavorite(tag)
        
        return TagChip(tag: tag) {
            favoriteTags.toggle(tag)
        }
        .overlay(
            Group {
                if isFav {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 7))
                        .foregroundColor(Color(hex: "FF2D78"))
                        .offset(x: -4, y: -4)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                }
            }
        )
    }
    
    // MARK: - Read Button
    private var readButton: some View {
        VStack(spacing: 12) {
            Button {
                if let entry = historyEntry, entry.lastPage > 0 {
                    startPage = entry.lastPage
                } else {
                    startPage = 0
                }
                showReader = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "book.fill")
                        .font(.body.weight(.semibold))
                    
                    if let entry = historyEntry, entry.lastPage > 0 {
                        Text("Continue from Page \(entry.lastPage + 1)")
                            .font(.body.weight(.bold))
                    } else {
                        Text("Start Reading")
                            .font(.body.weight(.bold))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "FF2D78"), Color(hex: "E91E63")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: Color(hex: "FF2D78").opacity(0.4), radius: 12, y: 4)
            }
            
            // Read from beginning (only if there's history)
            if let _ = historyEntry {
                Button {
                    startPage = 0
                    showReader = true
                } label: {
                    Text("Read from Beginning")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.06))
                        )
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundColor(.white.opacity(0.4))
            .textCase(.uppercase)
    }
    
    private func favoriteAllTags() {
        for tag in gallery.tags ?? [] {
            if !favoriteTags.isFavorite(tag) {
                favoriteTags.add(tag)
            }
        }
    }
}

#Preview {
    NavigationStack {
        GalleryDetailView(gallery: Gallery(
            id: 12345,
            title: "A Very Long Sample Gallery Title for Preview",
            japaneseTitle: "サンプルギャラリータイトル",
            artists: [Gallery.Artist(artist: "sample_artist", url: "/artist/sample")],
            groups: [Gallery.Group(group: "sample_group", url: "/group/sample")],
            parodys: [Gallery.Parody(parody: "original", url: "/series/original")],
            tags: [
                Tag(tag: "schoolgirl", url: "", gender: .female),
                Tag(tag: "glasses", url: "", gender: .male),
                Tag(tag: "full color", url: "", gender: nil),
            ],
            characters: [Gallery.Character(character: "character_name", url: "/char/test")],
            language: "japanese",
            languageLocalname: "日本語",
            type: "manga",
            date: "2024-01-15 12:30:00-05",
            files: [
                GalleryImage(name: "001.jpg", hash: "abc123def456", width: 1200, height: 1700, haswebp: 1, hasavif: 0, hasjxl: 0)
            ]
        ))
    }
    .environmentObject(HistoryManager.shared)
    .environmentObject(FavoriteTagsManager.shared)
    .preferredColorScheme(.dark)
}
