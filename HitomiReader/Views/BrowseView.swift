// BrowseView.swift
// HitomiReader
//
// Browseable gallery grid with infinite scrolling and pull-to-refresh.
// Fetches gallery IDs in pages of 25, then loads gallery info as cells appear.

import SwiftUI

@MainActor
class BrowseViewModel: ObservableObject {
    @Published var galleries: [Gallery] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?
    
    private var currentPage = 0
    private let perPage = 25
    private var loadedIDs: Set<Int> = []
    private var allIDs: [Int] = []
    private var hasMorePages = true
    
    func loadInitial() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        currentPage = 0
        loadedIDs.removeAll()
        allIDs.removeAll()
        galleries.removeAll()
        
        await loadPage()
        isLoading = false
    }
    
    func loadMore() async {
        guard !isLoadingMore && hasMorePages else { return }
        isLoadingMore = true
        currentPage += 1
        await loadPage()
        isLoadingMore = false
    }
    
    private func loadPage() async {
        do {
            let ids = try await HitomiAPI.shared.fetchGalleryIDs(
                page: currentPage,
                perPage: perPage,
                language: SettingsManager.shared.preferredLanguage
            )
            
            if ids.isEmpty {
                hasMorePages = false
                return
            }
            
            allIDs.append(contentsOf: ids)
            
            // Fetch gallery info for each ID concurrently
            await withTaskGroup(of: Gallery?.self) { group in
                for id in ids {
                    guard !loadedIDs.contains(id) else { continue }
                    loadedIDs.insert(id)
                    
                    group.addTask {
                        try? await HitomiAPI.shared.fetchGalleryInfo(id: id)
                    }
                }
                
                for await gallery in group {
                    if let gallery = gallery {
                        galleries.append(gallery)
                    }
                }
            }
            
            // Sort galleries to match ID order
            let idOrder = Dictionary(uniqueKeysWithValues: allIDs.enumerated().map { ($1, $0) })
            galleries.sort { (idOrder[$0.id] ?? 0) < (idOrder[$1.id] ?? 0) }
            
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct BrowseView: View {
    @EnvironmentObject var settings: SettingsManager
    @StateObject private var viewModel = BrowseViewModel()
    @State private var showSettings = false
    
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    var body: some View {
        ZStack {
            // Background
            Color(hex: "0D0D0D").ignoresSafeArea()
            
            if viewModel.isLoading && viewModel.galleries.isEmpty {
                loadingView
            } else if let error = viewModel.errorMessage, viewModel.galleries.isEmpty {
                errorView(error)
            } else {
                galleryGrid
            }
        }
        .navigationTitle("Browse")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .foregroundColor(Color(hex: "FF2D78"))
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .task {
            if viewModel.galleries.isEmpty {
                await viewModel.loadInitial()
            }
        }
        .refreshable {
            await viewModel.loadInitial()
        }
    }
    
    // MARK: - Gallery Grid
    private var galleryGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(viewModel.galleries) { gallery in
                    NavigationLink(destination: GalleryDetailView(gallery: gallery)) {
                        GalleryCard(gallery: gallery)
                    }
                    .buttonStyle(PressedScaleButtonStyle())
                    .onAppear {
                        // Infinite scroll: load more when near the end
                        if gallery.id == viewModel.galleries.last?.id {
                            Task {
                                await viewModel.loadMore()
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)
            .padding(.bottom, 20)
            
            // Loading more indicator
            if viewModel.isLoadingMore {
                HStack(spacing: 12) {
                    ProgressView()
                        .tint(Color(hex: "FF2D78"))
                    Text("Loading more…")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.vertical, 20)
            }
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(Color(hex: "FF2D78"))
            Text("Loading galleries…")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.5))
        }
    }
    
    // MARK: - Error View
    private func errorView(_ message: String) -> some View {
        let isDNS = message.lowercased().contains("hostname could not be found") ||
                    message.lowercased().contains("cannot find host") ||
                    message.lowercased().contains("code=-1003") ||
                    message.lowercased().contains("dns lookup")
        
        return VStack(spacing: 20) {
            Image(systemName: isDNS ? "network.slash" : "wifi.exclamationmark")
                .font(.system(size: 56))
                .foregroundColor(Color(hex: "FF2D78"))
            
            Text(isDNS ? "Connection / DNS Blocked" : "Something went wrong")
                .font(.title3.bold())
                .foregroundColor(.white)
            
            if isDNS {
                VStack(spacing: 12) {
                    Text("Hitomi.la could not be reached. If you are in Vietnam or another country with internet censoring, your ISP likely blocks hitomi.la. Note: browser-only extension VPNs will NOT work for native apps. You must use a system-wide VPN.")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Use a device-wide VPN or Cloudflare WARP app", systemImage: "checkmark.shield.fill")
                        Label("Change system DNS to Google (8.8.8.8) or Cloudflare (1.1.1.1)", systemImage: "checkmark.shield.fill")
                    }
                    .font(.caption)
                    .foregroundColor(Color(hex: "FF2D78"))
                    .padding(.top, 4)
                }
                .padding(.horizontal, 30)
            } else {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Button {
                Task { await viewModel.loadInitial() }
            } label: {
                Label("Try Again", systemImage: "arrow.clockwise")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color(hex: "FF2D78"))
                    .clipShape(Capsule())
            }
            .buttonStyle(PressedScaleButtonStyle())
        }
    }
}

#Preview {
    NavigationStack {
        BrowseView()
    }
    .environmentObject(SettingsManager.shared)
    .environmentObject(HistoryManager.shared)
    .environmentObject(FavoriteTagsManager.shared)
    .environmentObject(HitomiAPI.shared)
    .preferredColorScheme(.dark)
}
