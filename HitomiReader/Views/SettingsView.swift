// SettingsView.swift
// HitomiReader
//
// Settings sheet for language, reader direction, clear data, and app info.

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: SettingsManager
    @EnvironmentObject var history: HistoryManager
    @EnvironmentObject var favoriteTags: FavoriteTagsManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var showClearHistoryAlert = false
    @State private var showClearFavoritesAlert = false
    @State private var showResetAlert = false
    
    // Language options
    private let languages: [(id: String, name: String)] = [
        ("all", "All Languages"),
        ("english", "English"),
        ("japanese", "日本語 (Japanese)"),
        ("korean", "한국어 (Korean)"),
        ("chinese", "中文 (Chinese)"),
        ("vietnamese", "Tiếng Việt (Vietnamese)")
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "0D0D0D").ignoresSafeArea()
                
                List {
                    // MARK: - Reading Preferences
                    Section {
                        // Language Picker
                        Picker(selection: $settings.preferredLanguage) {
                            ForEach(languages, id: \.id) { lang in
                                Text(lang.name).tag(lang.id)
                            }
                        } label: {
                            Label("Language", systemImage: "globe")
                                .foregroundColor(.white)
                        }
                        .tint(.white.opacity(0.6))
                        .listRowBackground(Color.white.opacity(0.04))
                        .onChange(of: settings.preferredLanguage) { _ in
                            settings.save()
                        }
                        
                        // Reader Direction
                        Picker(selection: $settings.readerDirection) {
                            ForEach(ReaderDirection.allCases, id: \.rawValue) { dir in
                                Text(dir.rawValue).tag(dir)
                            }
                        } label: {
                            Label("Reading Direction", systemImage: "book.pages")
                                .foregroundColor(.white)
                        }
                        .tint(.white.opacity(0.6))
                        .listRowBackground(Color.white.opacity(0.04))
                        .onChange(of: settings.readerDirection) { _ in
                            settings.save()
                        }
                    } header: {
                        sectionHeader("Reading Preferences")
                    }
                    
                    // MARK: - Data Management
                    Section {
                        // Clear History
                        Button {
                            showClearHistoryAlert = true
                        } label: {
                            Label {
                                HStack {
                                    Text("Clear History")
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text("\(history.entries.count) items")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.35))
                                }
                            } icon: {
                                Image(systemName: "clock.arrow.circlepath")
                                    .foregroundColor(.orange)
                            }
                        }
                        .listRowBackground(Color.white.opacity(0.04))
                        
                        // Clear Favorites
                        Button {
                            showClearFavoritesAlert = true
                        } label: {
                            Label {
                                HStack {
                                    Text("Clear Favorites")
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text("\(favoriteTags.tags.count) tags")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.35))
                                }
                            } icon: {
                                Image(systemName: "heart.slash")
                                    .foregroundColor(Color(hex: "FF2D78"))
                            }
                        }
                        .listRowBackground(Color.white.opacity(0.04))
                    } header: {
                        sectionHeader("Data")
                    }
                    
                    // MARK: - About
                    Section {
                        HStack {
                            Label("Version", systemImage: "info.circle")
                                .foregroundColor(.white)
                            Spacer()
                            Text("1.0.0")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.4))
                        }
                        .listRowBackground(Color.white.opacity(0.04))
                        
                        HStack {
                            Label("Build", systemImage: "hammer")
                                .foregroundColor(.white)
                            Spacer()
                            Text("2024.1")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.4))
                        }
                        .listRowBackground(Color.white.opacity(0.04))
                    } header: {
                        sectionHeader("About")
                    }
                    
                    // MARK: - Danger Zone
                    Section {
                        Button {
                            showResetAlert = true
                        } label: {
                            Label("Reset All Settings", systemImage: "arrow.counterclockwise")
                                .foregroundColor(.red.opacity(0.8))
                        }
                        .listRowBackground(Color.red.opacity(0.06))
                    } header: {
                        sectionHeader("Advanced")
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "FF2D78"))
                    .fontWeight(.semibold)
                }
            }
            // Clear History Alert
            .alert("Clear History", isPresented: $showClearHistoryAlert) {
                Button("Clear", role: .destructive) {
                    history.clearAll()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will remove all \(history.entries.count) reading history entries.")
            }
            // Clear Favorites Alert
            .alert("Clear Favorites", isPresented: $showClearFavoritesAlert) {
                Button("Clear", role: .destructive) {
                    favoriteTags.clearAll()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will remove all \(favoriteTags.tags.count) favorite tags.")
            }
            // Reset Alert
            .alert("Reset All Settings", isPresented: $showResetAlert) {
                Button("Reset", role: .destructive) {
                    settings.preferredLanguage = "all"
                    settings.readerDirection = .rtl
                    settings.save()
                    history.clearAll()
                    favoriteTags.clearAll()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will reset all preferences and clear all saved data. This cannot be undone.")
            }
        }
    }
    
    // MARK: - Section Header
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundColor(.white.opacity(0.4))
            .textCase(.uppercase)
    }
}

#Preview {
    SettingsView()
        .environmentObject(SettingsManager.shared)
        .environmentObject(HistoryManager.shared)
        .environmentObject(FavoriteTagsManager.shared)
        .preferredColorScheme(.dark)
}
