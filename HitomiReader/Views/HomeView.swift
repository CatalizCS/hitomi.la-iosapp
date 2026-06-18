// HomeView.swift
// HitomiReader
//
// Main tab-based navigation with 4 sections:
// Browse, Search, History, and Favorites.

import SwiftUI

struct HomeView: View {
    @State private var selectedTab: Tab = .browse
    
    enum Tab: String, CaseIterable {
        case browse, search, history, favorites
        
        var icon: String {
            switch self {
            case .browse: return "house.fill"
            case .search: return "magnifyingglass"
            case .history: return "clock.fill"
            case .favorites: return "books.vertical.fill"
            }
        }
        
        var label: String {
            switch self {
            case .browse: return "Browse"
            case .search: return "Search"
            case .history: return "History"
            case .favorites: return "Library"
            }
        }
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // MARK: - Browse Tab
            NavigationStack {
                BrowseView()
            }
            .tabItem {
                Label(Tab.browse.label, systemImage: Tab.browse.icon)
            }
            .tag(Tab.browse)
            
            // MARK: - Search Tab
            NavigationStack {
                SearchView()
            }
            .tabItem {
                Label(Tab.search.label, systemImage: Tab.search.icon)
            }
            .tag(Tab.search)
            
            // MARK: - History Tab
            NavigationStack {
                HistoryView()
            }
            .tabItem {
                Label(Tab.history.label, systemImage: Tab.history.icon)
            }
            .tag(Tab.history)
            
            // MARK: - Library Tab
            NavigationStack {
                LibraryView()
            }
            .tabItem {
                Label(Tab.favorites.label, systemImage: Tab.favorites.icon)
            }
            .tag(Tab.favorites)
        }
        .tint(Color(hex: "FF2D78"))
    }
}

#Preview {
    HomeView()
        .environmentObject(SettingsManager.shared)
        .environmentObject(HistoryManager.shared)
        .environmentObject(FavoriteTagsManager.shared)
        .environmentObject(HitomiAPI.shared)
        .preferredColorScheme(.dark)
}
