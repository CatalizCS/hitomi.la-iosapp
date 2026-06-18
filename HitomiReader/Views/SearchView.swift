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
    
    private var currentPage = 0
    private let perPage = 25
    private var hasMorePages = true
    
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
        
        isSearching = true
        hasSearched = true
        errorMessage = nil
        currentPage = 0
        results.removeAll()
        hasMorePages = true
        
        // Parse "type:name" format
        let (type, name) = parseQuery(query)
        
        await fetchResults(type: type, name: name)
        isSearching = false
    }
    
    func loadMore() async {
        guard !isLoadingMore && hasMorePages && hasSearched else { return }
        isLoadingMore = true
        currentPage += 1
        
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let (type, name) = parseQuery(query)
        
        await fetchResults(type: type, name: name)
        isLoadingMore = false
    }
    
    /// Search by specific tag type and name (e.g., from FavoriteTagsView)
    func searchByTag(type: String, name: String) async {
        searchText = "\(type):\(name)"
        selectedType = .all
        isSearching = true
        hasSearched = true
        errorMessage = nil
        currentPage = 0
        results.removeAll()
        hasMorePages = true
        
        await fetchResults(type: type, name: name)
        isSearching = false
    }
    
    private func parseQuery(_ query: String) -> (type: String, name: String) {
        if query.contains(":") {
            let parts = query.split(separator: ":", maxSplits: 1)
            if parts.count == 2 {
                return (String(parts[0]).lowercased(), String(parts[1]).lowercased())
            }
        }
        
        // Use the selected filter type
        let type = selectedType == .all ? "tag" : selectedType.apiType
        return (type, query.lowercased())
    }
    
    private func fetchResults(type: String, name: String) async {
        do {
            let ids = try await HitomiAPI.shared.fetchGalleryIDsByTag(
                type: type,
                name: name,
                page: currentPage,
                perPage: perPage
            )
            
            if ids.isEmpty {
                hasMorePages = false
                return
            }
            
            // Fetch gallery info concurrently
            await withTaskGroup(of: Gallery?.self) { group in
                for id in ids {
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
                
                // Sort to match ID order
                let idOrder = Dictionary(uniqueKeysWithValues: ids.enumerated().map { ($1, $0) })
                newGalleries.sort { (idOrder[$0.id] ?? 0) < (idOrder[$1.id] ?? 0) }
                
                results.append(contentsOf: newGalleries)
            }
            
        } catch {
            errorMessage = error.localizedDescription
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
                if viewModel.isSearching && viewModel.results.isEmpty {
                    Spacer()
                    searchingIndicator
                    Spacer()
                } else if viewModel.hasSearched && viewModel.results.isEmpty && !viewModel.isSearching {
                    Spacer()
                    noResultsView
                    Spacer()
                } else if viewModel.results.isEmpty {
                    Spacer()
                    searchPrompt
                    Spacer()
                } else {
                    resultsGrid
                }
            }
        }
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.large)
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
