// BlacklistSettingsView.swift
// HitomiReader
//
// Screen to manage excluded tags that should be filtered out from browse and search results.

import SwiftUI

struct BlacklistSettingsView: View {
    @EnvironmentObject var settings: SettingsManager
    @State private var newTag = ""
    @State private var suggestions: [Tag] = []
    @State private var suggestionsTask: Task<Void, Never>? = nil
    
    var body: some View {
        ZStack {
            Color(hex: "0D0D0D").ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Add Tag Section
                VStack(alignment: .leading, spacing: 10) {
                    Text("Add Excluded Tag")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white.opacity(0.4))
                        .textCase(.uppercase)
                    
                    HStack(spacing: 12) {
                        TextField("e.g. schoolgirl, male:guro", text: $newTag)
                            .font(.body)
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .onChange(of: newTag) { _ in
                                fetchSuggestions()
                            }
                        
                        Button {
                            addTag(newTag)
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title)
                                .foregroundColor(Color(hex: "FF2D78"))
                        }
                        .disabled(newTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)
                
                // Suggestions List Overlay
                if !suggestions.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(suggestions) { tag in
                                Button {
                                    addTag(tag.displayName)
                                } label: {
                                    HStack {
                                        Image(systemName: "tag.fill")
                                            .foregroundColor(.white.opacity(0.4))
                                        Text(tag.displayName)
                                            .foregroundColor(.white)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                }
                                .buttonStyle(.plain)
                                
                                Divider().background(Color.white.opacity(0.08))
                            }
                        }
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color(hex: "1C1C1E")))
                        .padding(.horizontal, 16)
                    }
                    .frame(maxHeight: 180)
                    .transition(.opacity)
                }
                
                // Excluded Tags List
                VStack(alignment: .leading, spacing: 10) {
                    Text("Currently Excluded")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white.opacity(0.4))
                        .textCase(.uppercase)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                    
                    if settings.blacklistedTags.isEmpty {
                        VStack(spacing: 12) {
                            Spacer()
                            Image(systemName: "eye")
                                .font(.system(size: 40))
                                .foregroundColor(.white.opacity(0.15))
                            Text("No Excluded Tags")
                                .font(.subheadline.bold())
                                .foregroundColor(.white.opacity(0.4))
                            Text("Any tag you add here will be filtered out from browse and search feeds.")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.3))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List {
                            ForEach(settings.blacklistedTags, id: \.self) { tag in
                                HStack {
                                    Image(systemName: "nosign")
                                        .foregroundColor(.red.opacity(0.7))
                                    Text(tag)
                                        .foregroundColor(.white)
                                    Spacer()
                                }
                                .listRowBackground(Color.white.opacity(0.04))
                            }
                            .onDelete(perform: deleteTags)
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Blacklisted Tags")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func addTag(_ tagStr: String) {
        let clean = tagStr.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !clean.isEmpty else { return }
        
        if !settings.blacklistedTags.contains(clean) {
            settings.blacklistedTags.append(clean)
        }
        
        newTag = ""
        suggestions = []
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private func deleteTags(at offsets: IndexSet) {
        settings.blacklistedTags.remove(atOffsets: offsets)
    }
    
    private func fetchSuggestions() {
        suggestionsTask?.cancel()
        let query = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else {
            suggestions = []
            return
        }
        
        suggestionsTask = Task {
            try? await Task.sleep(nanoseconds: 200_000_000)
            guard !Task.isCancelled else { return }
            
            if let fetched = try? await HitomiAPI.shared.fetchTagSuggestions(query: query) {
                guard !Task.isCancelled else { return }
                self.suggestions = fetched
            }
        }
    }
}

#Preview {
    NavigationStack {
        BlacklistSettingsView()
            .environmentObject(SettingsManager.shared)
    }
}
