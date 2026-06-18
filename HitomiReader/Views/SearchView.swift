// SearchView.swift
// HitomiReader
//
// Tag-based search interface with type filters.
// Supports search formats like "female:schoolgirl" or just "schoolgirl".
// Displays results in a gallery grid.

import SwiftUI

@MainActor
class SearchViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var selectedType: TagFilterType = .all
    @Published var results: [Gallery] = []
    @Published var isSearching = false
    @Published var hasSearched = false
    @Published var errorMessage: String?
    @Published var isLoadingMore = false
    @Published var tagSuggestions: [Tag] = []
    @Published var sortOrder: SortOrder = .latest
    
    private var suggestionsTask: Task<Void, Never>?
    private var currentPage = 0
    private let perPage = 25
    private var hasMorePages = true
    private var allIDs: [Int] = []
    
    enum TagFilterType: String, CaseIterable {
        case all = "All"
        case female = "Female"
        case male = "Male"
        case artist = "Artist"
        case group = "Group"
        case series = "Series"
        case character = "Character"
        
        var apiType: String {
            switch self {
            case .all: return "tag"
            case .female: return "female"
            case .male: return "male"
            case .artist: return "artist"
            case .group: return "group"
            case .series: return "series"
            case .character: return "character"
            }
        }
    }
    
    func search() async {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        
        tagSuggestions.removeAll()
        isSearching = true
        hasSearched = true
        errorMessage = nil
        currentPage = 0
        results.removeAll()
        allIDs.removeAll()
        hasMorePages = true
        
        await fetchResults()
        isSearching = false
    }
    
    func loadMore() async {
        guard !isLoadingMore && hasMorePages && hasSearched else { return }
        isLoadingMore = true
        currentPage += 1
        
        await fetchResults()
        isLoadingMore = false
    }
    
    /// Search by specific tag type and name (e.g., from FavoriteTagsView)
    func searchByTag(type: String, name: String) async {
        searchText = "\(type):\(name)"
        selectedType = .all
        tagSuggestions.removeAll()
        isSearching = true
        hasSearched = true
        errorMessage = nil
        currentPage = 0
        results.removeAll()
        allIDs.removeAll()
        hasMorePages = true
        
        await fetchResults()
        isSearching = false
    }
    
    func updateSuggestions() {
        suggestionsTask?.cancel()
        
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else {
            tagSuggestions = []
            return
        }
        
        suggestionsTask = Task {
            try? await Task.sleep(nanoseconds: 200_000_000)
            guard !Task.isCancelled else { return }
            
            do {
                let suggestions = try await HitomiAPI.shared.fetchTagSuggestions(query: query)
                guard !Task.isCancelled else { return }
                self.tagSuggestions = suggestions
            } catch {
                // Ignore suggestions errors
            }
        }
    }
    
    private func parseQueryTags(_ query: String) -> [Tag] {
        let parts = query.split(separator: " ")
        var tags: [Tag] = []
        for part in parts {
            let tagStr = String(part).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !tagStr.isEmpty else { continue }
            
            var type = selectedType == .all ? "tag" : selectedType.apiType
            var name = tagStr
            
            if tagStr.contains(":") {
                let subParts = tagStr.split(separator: ":", maxSplits: 1)
                if subParts.count == 2 {
                    let typePart = String(subParts[0]).lowercased()
                    let namePart = String(subParts[1])
                    
                    let validTypes = ["artist", "group", "type", "language", "series", "character", "male", "female", "tag"]
                    if validTypes.contains(typePart) {
                        type = typePart
                        name = namePart
                    }
                }
            }
            
            let normalizedName = name.replacingOccurrences(of: " ", with: "_").lowercased()
            let gender = Tag.Gender(rawValue: type)
            let tagUrl = "/tag/\(type == "tag" ? "" : type + ":")\(normalizedName)-all.html"
            
            tags.append(Tag(tag: normalizedName, url: tagUrl, gender: gender))
        }
        return tags
    }
    
    private func fetchResults() async {
        do {
            if allIDs.isEmpty {
                let tags = parseQueryTags(searchText)
                guard !tags.isEmpty else {
                    hasMorePages = false
                    return
                }
                
                let ids = try await HitomiAPI.shared.fetchGalleryIDsByTags(
                    tags: tags,
                    language: SettingsManager.shared.preferredLanguage,
                    orderBy: sortOrder.apiValue
                )
                
                allIDs = ids
                
                if allIDs.isEmpty {
                    hasMorePages = false
                    return
                }
            }
            
            let startIndex = currentPage * perPage
            guard startIndex < allIDs.count else {
                hasMorePages = false
                return
            }
            
            let endIndex = min(startIndex + perPage, allIDs.count)
            let pageIDs = Array(allIDs[startIndex..<endIndex])
            
            if pageIDs.isEmpty {
                hasMorePages = false
                return
            }
            
            await withTaskGroup(of: Gallery?.self) { group in
                for id in pageIDs {
                    group.addTask {
                        try? await HitomiAPI.shared.fetchGalleryInfo(id: id)
                    }
                }
                
                var newGalleries: [Gallery] = []
                for await gallery in group {
                    if let gallery = gallery {
                        newGalleries.append(gallery)
                    }
                }
                
                let idOrder = Dictionary(uniqueKeysWithValues: pageIDs.enumerated().map { ($1, $0) })
                newGalleries.sort { (idOrder[$0.id] ?? 0) < (idOrder[$1.id] ?? 0) }
                
                if currentPage == 0 {
                    results = newGalleries
                } else {
                    results.append(contentsOf: newGalleries)
                }
            }
            
            hasMorePages = endIndex < allIDs.count
            
        } catch {
            errorMessage = error.localizedDescription
            hasMorePages = false
        }
    }
}

struct SearchView: View {
    @StateObject private var viewModel = SearchViewModel()
    @FocusState private var isSearchFocused: Bool
    
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    var body: some View {
        ZStack {
            Color(hex: "0D0D0D").ignoresSafeArea()
            
            VStack(spacing: 0) {
                // MARK: - Search Bar
                searchBar
                
                // MARK: - Type Filter
                typeFilter
                
                // MARK: - Content
                ZStack(alignment: .top) {
                    if viewModel.isSearching && viewModel.results.isEmpty {
                        VStack {
                            Spacer()
                            searchingIndicator
                            Spacer()
                        }
                    } else if viewModel.hasSearched && viewModel.results.isEmpty && !viewModel.isSearching {
                        VStack {
                            Spacer()
                            noResultsView
                            Spacer()
                        }
                    } else if viewModel.results.isEmpty {
                        VStack {
                            Spacer()
                            searchPrompt
                            Spacer()
                        }
                    } else {
                        resultsGrid
                    }
                    
                    // Autocomplete Suggestions Overlay
                    if !viewModel.tagSuggestions.isEmpty {
                        Color.black.opacity(0.65)
                            .ignoresSafeArea()
                            .onTapGesture {
                                viewModel.tagSuggestions = []
                                isSearchFocused = false
                            }
                        
                        suggestionsList
                            .transition(.opacity)
                    }
                }
        }
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.large)
        .onChange(of: viewModel.searchText) { _ in
            viewModel.updateSuggestions()
        }
        .onChange(of: viewModel.selectedType) { _ in
            Task { await viewModel.search() }
        }
        .onChange(of: viewModel.sortOrder) { _ in
            Task { await viewModel.search() }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    ForEach(SortOrder.allCases) { order in
                        Button {
                            viewModel.sortOrder = order
                        } label: {
                            HStack {
                                Text(order.displayName)
                                if viewModel.sortOrder == order {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .foregroundColor(Color(hex: "FF2D78"))
                }
            }
        }
    }
    
    // MARK: - Search Bar
    private var searchBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.white.opacity(0.4))
                    .font(.body)
                
                TextField("Search tags…", text: $viewModel.searchText)
                    .font(.body)
                    .foregroundColor(.white)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .focused($isSearchFocused)
                    .submitLabel(.search)
                    .onSubmit {
                        Task { await viewModel.search() }
                    }
                
                if !viewModel.searchText.isEmpty {
                    Button {
                        viewModel.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white.opacity(0.3))
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSearchFocused ? Color(hex: "FF2D78").opacity(0.5) : Color.white.opacity(0.08), lineWidth: 1)
            )
            
            if isSearchFocused {
                Button("Cancel") {
                    isSearchFocused = false
                    viewModel.searchText = ""
                }
                .font(.subheadline)
                .foregroundColor(Color(hex: "FF2D78"))
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .animation(.easeInOut(duration: 0.2), value: isSearchFocused)
    }
    
    // MARK: - Type Filter
    private var typeFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SearchViewModel.TagFilterType.allCases, id: \.self) { type in
                    filterChip(type)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
    
    private func filterChip(_ type: SearchViewModel.TagFilterType) -> some View {
        let isSelected = viewModel.selectedType == type
        
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                viewModel.selectedType = type
            }
        } label: {
            Text(type.rawValue)
                .font(.caption.weight(.semibold))
                .foregroundColor(isSelected ? .white : .white.opacity(0.5))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(isSelected ? Color(hex: "FF2D78") : Color.white.opacity(0.06))
                )
        }
    }
    
    // MARK: - Results Grid
    private var resultsGrid: some View {
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
            .padding(.top, 4)
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
    
    // MARK: - Search Prompt
    private var searchPrompt: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.15))
            
            Text("Search by Tag")
                .font(.headline)
                .foregroundColor(.white.opacity(0.5))
            
            VStack(spacing: 4) {
                Text("Try searching for tags like:")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.3))
                
                Text("\"female:schoolgirl\" or \"full color\"")
                    .font(.caption.weight(.medium))
                    .foregroundColor(Color(hex: "FF2D78").opacity(0.7))
            }
        }
    }
    
    // MARK: - Searching Indicator
    private var searchingIndicator: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(Color(hex: "FF2D78"))
            Text("Searching…")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.5))
        }
    }
    
    // MARK: - No Results
    private var noResultsView: some View {
        let error = viewModel.errorMessage ?? ""
        let isDNS = error.lowercased().contains("hostname could not be found") ||
                    error.lowercased().contains("cannot find host") ||
                    error.lowercased().contains("code=-1003") ||
                    error.lowercased().contains("dns lookup")
        
        return VStack(spacing: 16) {
            Image(systemName: isDNS ? "network.slash" : "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(isDNS ? Color(hex: "FF2D78") : .white.opacity(0.15))
            
            Text(isDNS ? "Connection / DNS Blocked" : "No Results Found")
                .font(.headline)
                .foregroundColor(.white)
            
            if isDNS {
                VStack(spacing: 8) {
                    Text("Hitomi.la could not be reached. If you are in Vietnam, your ISP likely blocks it.")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                    Text("Please enable a system-wide VPN (e.g. Cloudflare WARP app) and search again. Browser-only extensions will not work.")
                        .font(.caption2)
                        .foregroundColor(Color(hex: "FF2D78"))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 40)
            } else if !error.isEmpty {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.3))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            } else {
                Text("Try a different search term or filter")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.3))
            }
        }
    }

    // MARK: - Autocomplete Suggestions List
    private var suggestionsList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(viewModel.tagSuggestions) { tag in
                    Button {
                        viewModel.searchText = tag.displayName
                        viewModel.tagSuggestions = []
                        isSearchFocused = false
                        Task { await viewModel.search() }
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "tag.fill")
                                .font(.subheadline)
                                .foregroundColor(tag.gender == .female ? Color(hex: "FF2D78") : (tag.gender == .male ? .blue : .white.opacity(0.4)))
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(tag.displayName)
                                    .font(.body)
                                    .foregroundColor(.white)
                                
                                if let count = tag.count {
                                    Text("\(count) items")
                                        .font(.caption2)
                                        .foregroundColor(.white.opacity(0.45))
                                }
                            }
                            
                            Spacer()
                            
                            Image(systemName: "arrow.up.backward")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.25))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PressedScaleButtonStyle())
                    
                    Divider()
                        .background(Color.white.opacity(0.08))
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: "1A1A1A"))
            )
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .frame(maxHeight: 280)
    }
}

#Preview {
    NavigationStack {
        SearchView()
    }
    .environmentObject(SettingsManager.shared)
    .environmentObject(HistoryManager.shared)
    .environmentObject(FavoriteTagsManager.shared)
    .environmentObject(HitomiAPI.shared)
    .preferredColorScheme(.dark)
}
