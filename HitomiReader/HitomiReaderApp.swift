// HitomiReaderApp.swift
// HitomiReader
//
// Main entry point for the Hitomi Reader app.
// Shows onboarding on first launch, then the main tab interface.

import SwiftUI

@main
struct HitomiReaderApp: App {
    // MARK: - Environment Objects
    @StateObject private var settings = SettingsManager.shared
    @StateObject private var history = HistoryManager.shared
    @StateObject private var favoriteTags = FavoriteTagsManager.shared
    @StateObject private var favoriteGalleries = FavoriteGalleriesManager.shared
    @StateObject private var downloads = DownloadManager.shared
    @StateObject private var readingStatuses = ReadingStatusManager.shared
    @StateObject private var api = HitomiAPI.shared
    
    @Environment(\.scenePhase) private var scenePhase
    @State private var isLocked = false
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                Group {
                    if settings.hasCompletedOnboarding {
                        HomeView()
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    } else {
                        OnboardingView()
                            .transition(.opacity)
                    }
                }
                
                if isLocked && settings.isPrivacyLockEnabled {
                    PrivacyLockView {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isLocked = false
                        }
                    }
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.5), value: settings.hasCompletedOnboarding)
            .environmentObject(settings)
            .environmentObject(history)
            .environmentObject(favoriteTags)
            .environmentObject(favoriteGalleries)
            .environmentObject(downloads)
            .environmentObject(readingStatuses)
            .environmentObject(api)
            .preferredColorScheme(.dark)
            .onAppear {
                isLocked = settings.isPrivacyLockEnabled
            }
            .onChange(of: scenePhase) { newPhase in
                if newPhase == .background {
                    if settings.isPrivacyLockEnabled {
                        isLocked = true
                    }
                }
            }
        }
    }
}
