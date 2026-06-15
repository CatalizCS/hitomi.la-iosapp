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
    @StateObject private var api = HitomiAPI.shared
    
    var body: some Scene {
        WindowGroup {
            Group {
                if settings.hasCompletedOnboarding {
                    HomeView()
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                } else {
                    OnboardingView()
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.5), value: settings.hasCompletedOnboarding)
            .environmentObject(settings)
            .environmentObject(history)
            .environmentObject(favoriteTags)
            .environmentObject(api)
            .preferredColorScheme(.dark)
        }
    }
}
