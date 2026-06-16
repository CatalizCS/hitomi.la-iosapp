// HistoryView.swift
// HitomiReader
//
// Reading history list with thumbnails, progress, timestamps.
// Supports swipe-to-delete and clear all.

import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var history: HistoryManager
    @State private var showClearConfirmation = false
    
    var body: some View {
        ZStack {
            Color(hex: "0D0D0D").ignoresSafeArea()
            
            if history.entries.isEmpty {
                emptyState
            } else {
                historyList
            }
        }
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if !history.entries.isEmpty {
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
            "Clear Reading History",
            isPresented: $showClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear All", role: .destructive) {
                withAnimation(.easeInOut) {
                    history.clearAll()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove all reading history. This action cannot be undone.")
        }
    }
    
    // MARK: - History List
    private var historyList: some View {
        List {
            ForEach(sortedEntries) { entry in
                NavigationLink {
                    HistoryGalleryLoader(galleryID: entry.galleryID)
                } label: {
                    historyRow(entry)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowSeparatorTint(Color.white.opacity(0.06))
            }
            .onDelete(perform: deleteEntries)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
    
    // MARK: - History Row
    private func historyRow(_ entry: HistoryManager.HistoryEntry) -> some View {
        HStack(spacing: 14) {
            // Thumbnail
            if let url = entry.thumbnailURL {
                AsyncImageView(url: url, contentMode: .fill, cornerRadius: 8)
                    .frame(width: 56, height: 78)
                    .clipped()
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: "1A1A2E"))
                    .frame(width: 56, height: 78)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.white.opacity(0.2))
                    )
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white)
                    .lineLimit(2)
                
                HStack(spacing: 12) {
                    // Page progress
                    Label("Page \(entry.lastPage + 1)", systemImage: "bookmark.fill")
                        .font(.caption)
                        .foregroundColor(Color(hex: "FF2D78"))
                    
                    // Relative timestamp
                    Text(relativeTime(entry.timestamp))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.35))
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.white.opacity(0.2))
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 56))
                .foregroundColor(.white.opacity(0.12))
            
            Text("No Reading History")
                .font(.headline)
                .foregroundColor(.white.opacity(0.5))
            
            Text("Galleries you read will appear here")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.3))
        }
    }
    
    // MARK: - Sorted Entries (most recent first)
    private var sortedEntries: [HistoryManager.HistoryEntry] {
        history.entries.sorted { $0.timestamp > $1.timestamp }
    }
    
    // MARK: - Delete
    private func deleteEntries(at offsets: IndexSet) {
        let sorted = sortedEntries
        for index in offsets {
            history.remove(galleryID: sorted[index].galleryID)
        }
    }
    
    // MARK: - Relative Time
    private func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - History Gallery Loader
/// Loads gallery info from ID when tapping a history entry

struct HistoryGalleryLoader: View {
    let galleryID: Int
    
    @State private var gallery: Gallery?
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        Group {
            if let gallery = gallery {
                GalleryDetailView(gallery: gallery)
            } else if isLoading {
                ZStack {
                    Color(hex: "0D0D0D").ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView()
                            .tint(Color(hex: "FF2D78"))
                        Text("Loading gallery…")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
            } else if let error = errorMessage {
                ZStack {
                    Color(hex: "0D0D0D").ignoresSafeArea()
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.title)
                            .foregroundColor(Color(hex: "FF2D78").opacity(0.6))
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
            }
        }
        .task {
            do {
                gallery = try await HitomiAPI.shared.fetchGalleryInfo(id: galleryID)
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

#Preview {
    NavigationStack {
        HistoryView()
    }
    .environmentObject(HistoryManager.shared)
    .preferredColorScheme(.dark)
}
