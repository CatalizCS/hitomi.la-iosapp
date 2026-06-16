// FavoriteTagsView.swift
// HitomiReader
//
// Grid/list of favorite saved tags, color-coded by type.
// Tap to search galleries by that tag, swipe to remove.

import SwiftUI

struct FavoriteTagsView: View {
    @EnvironmentObject var favoriteTags: FavoriteTagsManager
    @State private var showClearConfirmation = false
    
    var body: some View {
        ZStack {
            Color(hex: "0D0D0D").ignoresSafeArea()
            
            if favoriteTags.tags.isEmpty {
                emptyState
            } else {
                tagsList
            }
        }
        .navigationTitle("Favorites")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if !favoriteTags.tags.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showClearConfirmation = true
                    } label: {
                        Text("Clear All")
                            .font(.subheadline)
                            .foregroundColor(Color(hex: "FF2D78"))
                    }
                }
            }
        }
        .confirmationDialog(
            "Clear All Favorite Tags",
            isPresented: $showClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear All", role: .destructive) {
                withAnimation {
                    favoriteTags.clearAll()
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }
    
    // MARK: - Tags List
    private var tagsList: some View {
        List {
            // Group tags by type
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
    
    // MARK: - Tag Row
    private func tagRow(_ tag: Tag) -> some View {
        NavigationLink(destination: TagSearchResultsView(tag: tag)) {
            HStack(spacing: 14) {
                // Color indicator
                RoundedRectangle(cornerRadius: 4)
                    .fill(tagColor(for: tag.nozomiTagType))
                    .frame(width: 4, height: 32)
                
                // Gender prefix
                if tag.nozomiTagType == "female" {
                    Text("♀")
                        .font(.body.weight(.bold))
                        .foregroundColor(tagColor(for: "female"))
                } else if tag.nozomiTagType == "male" {
                    Text("♂")
                        .font(.body.weight(.bold))
                        .foregroundColor(tagColor(for: "male"))
                }
                
                // Tag name
                VStack(alignment: .leading, spacing: 2) {
                    Text(tag.tag)
                        .font(.body.weight(.medium))
                        .foregroundColor(.white)
                    
                    Text(tag.nozomiTagType)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.35))
                }
                
                Spacer()
                
                // Search icon
                Image(systemName: "magnifyingglass")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.25))
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
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
        }
    }
    
    // MARK: - Grouped Tags
    
    struct TagGroup: Identifiable {
        let type: String
        let tags: [Tag]
        var id: String { type }
    }
    
    private var groupedTags: [TagGroup] {
        let grouped = Dictionary(grouping: favoriteTags.tags) { $0.nozomiTagType }
        let order = ["female", "male", "artist", "group", "series", "character", "tag"]
        
        return order.compactMap { type in
            guard let tags = grouped[type], !tags.isEmpty else { return nil }
            return TagGroup(type: type, tags: tags.sorted { $0.tag < $1.tag })
        }
    }
    
    // MARK: - Tag Color
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
    
    // MARK: - Delete
    private func deleteTagsInGroup(group: TagGroup, offsets: IndexSet) {
        for index in offsets {
            let tag = group.tags[index]
            favoriteTags.remove(tag)
        }
    }
}

// MARK: - Tag Search Results View

struct TagSearchResultsView: View {
    let tag: Tag
    
    @StateObject private var viewModel = SearchViewModel()
    
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    var body: some View {
        ZStack {
            Color(hex: "0D0D0D").ignoresSafeArea()
            
            if viewModel.isSearching && viewModel.results.isEmpty {
                VStack(spacing: 16) {
                    ProgressView()
                        .tint(Color(hex: "FF2D78"))
                    Text("Searching \(tag.displayName)…")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.5))
                }
            } else if viewModel.results.isEmpty && viewModel.hasSearched {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 36))
                        .foregroundColor(.white.opacity(0.15))
                    Text("No results found")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.5))
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(viewModel.results) { gallery in
                            NavigationLink(destination: GalleryDetailView(gallery: gallery)) {
                                GalleryCard(gallery: gallery)
                            }
                            .buttonStyle(PressedScaleButtonStyle())
                            .onAppear {
                                if gallery.id == viewModel.results.last?.id {
                                    Task { await viewModel.loadMore() }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 8)
                    .padding(.bottom, 20)
                    
                    if viewModel.isLoadingMore {
                        HStack(spacing: 12) {
                            ProgressView().tint(Color(hex: "FF2D78"))
                            Text("Loading more…")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .padding(.vertical, 20)
                    }
                }
            }
        }
        .navigationTitle(tag.tag)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.searchByTag(type: tag.nozomiTagType, name: tag.tag)
        }
    }
}

#Preview {
    NavigationStack {
        FavoriteTagsView()
    }
    .environmentObject(FavoriteTagsManager.shared)
    .environmentObject(HistoryManager.shared)
    .environmentObject(HitomiAPI.shared)
    .preferredColorScheme(.dark)
}
