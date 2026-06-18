// LibraryView.swift
// HitomiReader
//
// Consolidated library view containing:
// 1. Comics: Favorites + Reading Status (Want to Read / Reading / Completed).
// 2. Tags: Favorite tag groupings.
// 3. Downloads: Offline downloaded galleries.

import SwiftUI

struct LibraryView: View {
    @EnvironmentObject var favoriteGalleries: FavoriteGalleriesManager
    @EnvironmentObject var favoriteTags: FavoriteTagsManager
    @EnvironmentObject var downloads: DownloadManager
    @EnvironmentObject var readingStatuses: ReadingStatusManager
    
    @State private var libraryTab: LibraryTab = .comics
    @State private var readingStatusFilter: ReadingStatus = .wantToRead // wantToRead, reading, completed, or favorites mock
    @State private var showClearTagsConfirmation = false
    
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    enum LibraryTab: String, CaseIterable, Identifiable {
        case comics = "Comics"
        case tags = "Tags"
        case downloads = "Downloads"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .comics: return "books.vertical.fill"
            case .tags: return "tag.fill"
            case .downloads: return "arrow.down.circle.fill"
            }
        }
    }
    
    // Custom filter for Comics segment
    enum ComicFilter: String, CaseIterable, Identifiable {
        case favorites = "Favorites"
        case wantToRead = "Want to Read"
        case reading = "Reading"
        case completed = "Completed"
        
        var id: String { rawValue }
        
        var status: ReadingStatus? {
            switch self {
            case .favorites: return nil
            case .wantToRead: return .wantToRead
            case .reading: return .reading
            case .completed: return .completed
            }
        }
        
        var viName: String {
            switch self {
            case .favorites: return "Yêu thích"
            case .wantToRead: return "Muốn đọc"
            case .reading: return "Đang đọc"
            case .completed: return "Đã xong"
            }
        }
    }
    
    @State private var comicFilter: ComicFilter = .favorites
    
    var body: some View {
        ZStack {
            Color(hex: "0D0D0D").ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Main Tab Picker
                Picker("Library Section", selection: $libraryTab) {
                    ForEach(LibraryTab.allCases) { tab in
                        Label(tab.rawValue, systemImage: tab.icon).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 12)
                
                Divider().background(Color.white.opacity(0.08))
                
                // Content Switcher
                switch libraryTab {
                case .comics:
                    comicsSection
                case .tags:
                    tagsSection
                case .downloads:
                    downloadsSection
                }
            }
        }
        .navigationTitle("Library")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Comics Section
    private var comicsSection: some View {
        VStack(spacing: 0) {
            // Horizontal sliding sub-filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ComicFilter.allCases) { filter in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                comicFilter = filter
                            }
                        } label: {
                            Text(filter.viName)
                                .font(.caption.weight(.semibold))
                                .foregroundColor(comicFilter == filter ? .white : .white.opacity(0.5))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(
                                    Capsule()
                                        .fill(comicFilter == filter ? Color(hex: "FF2D78") : Color.white.opacity(0.06))
                                )
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            
            Divider().background(Color.white.opacity(0.08))
            
            // Grid view of items
            ScrollView {
                if comicFilter == .favorites {
                    if favoriteGalleries.galleries.isEmpty {
                        emptyComicsState(icon: "heart.slash", title: "Không có truyện yêu thích", subtitle: "Thêm truyện vào mục yêu thích trong phần chi tiết truyện.")
                    } else {
                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(favoriteGalleries.galleries) { gallery in
                                NavigationLink(destination: GalleryDetailView(gallery: gallery)) {
                                    GalleryCard(gallery: gallery)
                                }
                                .buttonStyle(PressedScaleButtonStyle())
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.top, 10)
                    }
                } else if let status = comicFilter.status {
                    let records = readingStatuses.getRecords(for: status)
                    if records.isEmpty {
                        emptyComicsState(icon: "books.vertical", title: "Trống", subtitle: "Gán trạng thái đọc cho truyện trong phần chi tiết truyện.")
                    } else {
                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(records, id: \.galleryID) { record in
                                NavigationLink(destination: DeferredGalleryDetailView(galleryID: record.galleryID)) {
                                    let url = record.thumbnailURLString != nil ? URL(string: record.thumbnailURLString!) : nil
                                    LibraryGalleryCard(title: record.title, thumbnailURL: url)
                                }
                                .buttonStyle(PressedScaleButtonStyle())
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.top, 10)
                    }
                }
            }
        }
    }
    
    private func emptyComicsState(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 16) {
            Spacer(minLength: 60)
            Image(systemName: icon)
                .font(.system(size: 56))
                .foregroundColor(.white.opacity(0.12))
            
            Text(title)
                .font(.headline)
                .foregroundColor(.white.opacity(0.5))
            
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.3))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }
    
    // MARK: - Tags Section
    private var tagsSection: some View {
        Group {
            if favoriteTags.tags.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "heart.slash")
                        .font(.system(size: 56))
                        .foregroundColor(.white.opacity(0.12))
                    
                    Text("No Favorite Tags")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.5))
                    
                    Text("Tap tags in gallery details to save them")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.3))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    Spacer()
                }
            } else {
                List {
                    ForEach(groupedTags, id: \.type) { group in
                        Section {
                            ForEach(group.tags) { tag in
                                tagRow(tag)
                                    .listRowBackground(Color.clear)
                                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            }
                            .onDelete { offsets in
                                deleteTagsInGroup(group: group, offsets: offsets)
                            }
                        } header: {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(tagColor(for: group.type))
                                    .frame(width: 8, height: 8)
                                Text(group.type.capitalized)
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(.white.opacity(0.5))
                                    .textCase(.uppercase)
                                
                                Text("(\(group.tags.count))")
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.3))
                            }
                        }
                        .listRowSeparatorTint(Color.white.opacity(0.04))
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }
    
    // MARK: - Tag Row (copied from old FavoriteTagsView)
    private func tagRow(_ tag: Tag) -> some View {
        NavigationLink(destination: TagSearchResultsView(tag: tag)) {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(tagColor(for: tag.nozomiTagType))
                    .frame(width: 4, height: 32)
                
                if tag.nozomiTagType == "female" {
                    Text("♀")
                        .font(.body.weight(.bold))
                        .foregroundColor(tagColor(for: "female"))
                } else if tag.nozomiTagType == "male" {
                    Text("♂")
                        .font(.body.weight(.bold))
                        .foregroundColor(tagColor(for: "male"))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(tag.tag)
                        .font(.body.weight(.medium))
                        .foregroundColor(.white)
                    
                    Text(tag.nozomiTagType)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.35))
                }
                
                Spacer()
                
                Image(systemName: "magnifyingglass")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.25))
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
    
    private var groupedTags: [FavoriteTagsView.TagGroup] {
        let grouped = Dictionary(grouping: favoriteTags.tags) { $0.nozomiTagType }
        let order = ["female", "male", "artist", "group", "series", "character", "tag"]
        
        return order.compactMap { type in
            guard let tags = grouped[type], !tags.isEmpty else { return nil }
            return FavoriteTagsView.TagGroup(type: type, tags: tags.sorted { $0.tag < $1.tag })
        }
    }
    
    private func tagColor(for type: String) -> Color {
        switch type {
        case "female":    return Color(hex: "FF2D78")
        case "male":      return Color(hex: "4A9EFF")
        case "artist":    return Color(hex: "A855F7")
        case "group":     return Color(hex: "F97316")
        case "series":    return Color(hex: "22C55E")
        case "character": return Color(hex: "14B8A6")
        default:          return Color(hex: "6B7280")
        }
    }
    
    private func deleteTagsInGroup(group: FavoriteTagsView.TagGroup, offsets: IndexSet) {
        for index in offsets {
            let tag = group.tags[index]
            favoriteTags.remove(tag)
        }
    }
    
    // MARK: - Downloads Section
    private var downloadsSection: some View {
        ScrollView {
            if downloads.downloadedGalleries.isEmpty {
                emptyComicsState(icon: "arrow.down.circle", title: "Không có truyện tải về", subtitle: "Truyện đã tải về sẽ xuất hiện ở đây để bạn có thể đọc ngoại tuyến.")
            } else {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(downloads.downloadedGalleries) { gallery in
                        NavigationLink(destination: GalleryDetailView(gallery: gallery)) {
                            GalleryCard(gallery: gallery)
                        }
                        .buttonStyle(PressedScaleButtonStyle())
                        .contextMenu {
                            Button(role: .destructive) {
                                downloads.deleteDownload(galleryID: gallery.id)
                            } label: {
                                Label("Xóa bản tải", systemImage: "trash")
                            }
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 10)
            }
        }
    }
}

// MARK: - Library Gallery Card (Simple cover card for Status Records)
struct LibraryGalleryCard: View {
    let title: String
    let thumbnailURL: URL?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                AsyncImageView(
                    url: thumbnailURL,
                    contentMode: .fill,
                    cornerRadius: 0
                )
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
                
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
                
                VStack(alignment: .leading, spacing: 4) {
                    Spacer()
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .aspectRatio(0.7, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
    }
}

// MARK: - Deferred Gallery Detail View (Asynchronous loader for ID only)
struct DeferredGalleryDetailView: View {
    let galleryID: Int
    @State private var gallery: Gallery? = nil
    @State private var isLoading = true
    @State private var error: String? = nil
    
    var body: some View {
        Group {
            if let gallery = gallery {
                GalleryDetailView(gallery: gallery)
            } else if isLoading {
                ZStack {
                    Color(hex: "0D0D0D").ignoresSafeArea()
                    ProgressView().tint(Color(hex: "FF2D78"))
                }
            } else {
                ZStack {
                    Color(hex: "0D0D0D").ignoresSafeArea()
                    VStack(spacing: 16) {
                        Text("Tải thông tin thất bại")
                            .foregroundColor(.white.opacity(0.6))
                        Button("Thử lại") {
                            loadGallery()
                        }
                        .foregroundColor(Color(hex: "FF2D78"))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Capsule().stroke(Color(hex: "FF2D78"), lineWidth: 1))
                    }
                }
            }
        }
        .task {
            loadGallery()
        }
    }
    
    private func loadGallery() {
        isLoading = true
        error = nil
        Task {
            do {
                // Check local downloads first
                let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                let metadataURL = docs.appendingPathComponent("downloads/\(galleryID)/metadata.json")
                if FileManager.default.fileExists(atPath: metadataURL.path) {
                    let data = try Data(contentsOf: metadataURL)
                    self.gallery = try JSONDecoder().decode(Gallery.self, from: data)
                    self.isLoading = false
                    return
                }
                
                let fetched = try await HitomiAPI.shared.fetchGalleryInfo(id: galleryID)
                self.gallery = fetched
            } catch {
                self.error = error.localizedDescription
            }
            self.isLoading = false
        }
    }
}
