// OnboardingView.swift
// HitomiReader
//
// First-launch onboarding with language & reader direction selection.
// Features an animated gradient background and smooth transitions.

import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var settings: SettingsManager
    
    // MARK: - State
    @State private var selectedLanguage: String = "all"
    @State private var selectedDirection: ReaderDirection = .rtl
    @State private var currentStep: Int = 0
    @State private var animateGradient = false
    @State private var logoScale: CGFloat = 0.5
    @State private var logoOpacity: Double = 0
    @State private var contentOpacity: Double = 0
    
    // MARK: - Language Options
    private let languages: [(id: String, name: String, flag: String)] = [
        ("all", "All Languages", "🌐"),
        ("english", "English", "🇬🇧"),
        ("japanese", "日本語", "🇯🇵"),
        ("korean", "한국어", "🇰🇷"),
        ("chinese", "中文", "🇨🇳"),
        ("vietnamese", "Tiếng Việt", "🇻🇳")
    ]
    
    var body: some View {
        ZStack {
            // MARK: - Animated Gradient Background
            animatedBackground
            
            VStack(spacing: 0) {
                Spacer()
                
                // MARK: - Logo & Title
                logoSection
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)
                
                Spacer()
                    .frame(height: 40)
                
                // MARK: - Content Steps
                Group {
                    if currentStep == 0 {
                        languageStep
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    } else {
                        readerDirectionStep
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    }
                }
                .opacity(contentOpacity)
                
                Spacer()
                
                // MARK: - Navigation Buttons
                bottomButtons
                    .opacity(contentOpacity)
                
                Spacer()
                    .frame(height: 50)
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.3)) {
                contentOpacity = 1.0
            }
            withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                animateGradient = true
            }
        }
    }
    
    // MARK: - Animated Background
    private var animatedBackground: some View {
        ZStack {
            Color(hex: "0D0D0D")
            
            LinearGradient(
                colors: [Color(hex: "1A1A2E"), Color(hex: "2D1B3D").opacity(0.8), .clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .opacity(animateGradient ? 0.3 : 0.8)
            
            LinearGradient(
                colors: [Color(hex: "2D1B3D"), Color(hex: "1B2D3D").opacity(0.8), .clear],
                startPoint: .bottomTrailing,
                endPoint: .topLeading
            )
            .opacity(animateGradient ? 0.8 : 0.3)
        }
        .ignoresSafeArea()
    }
    
    // MARK: - Logo Section
    private var logoSection: some View {
        VStack(spacing: 16) {
            // App icon circle
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(hex: "FF2D78").opacity(0.3), .clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: 60
                        )
                    )
                    .frame(width: 120, height: 120)
                
                Image(systemName: "book.pages.fill")
                    .font(.system(size: 48, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "FF2D78"), Color(hex: "FF6B9D")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            Text("Hitomi Reader")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Text("Your premium manga reading experience")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.6))
        }
    }
    
    // MARK: - Language Selection Step
    private var languageStep: some View {
        VStack(spacing: 20) {
            // Step header
            stepHeader(
                icon: "globe",
                title: "Choose Language",
                subtitle: "Select your preferred content language"
            )
            
            // Language grid
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                ForEach(languages, id: \.id) { lang in
                    languageButton(lang)
                }
            }
        }
    }
    
    // MARK: - Reader Direction Step
    private var readerDirectionStep: some View {
        VStack(spacing: 20) {
            stepHeader(
                icon: "book.pages",
                title: "Reading Direction",
                subtitle: "How would you like to read?"
            )
            
            VStack(spacing: 12) {
                ForEach(ReaderDirection.allCases, id: \.rawValue) { direction in
                    directionButton(direction)
                }
            }
        }
    }
    
    // MARK: - Step Header
    private func stepHeader(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 8) {
            Label(title, systemImage: icon)
                .font(.title2.bold())
                .foregroundColor(.white)
            
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(.bottom, 8)
    }
    
    // MARK: - Language Button
    private func languageButton(_ lang: (id: String, name: String, flag: String)) -> some View {
        let isSelected = selectedLanguage == lang.id
        
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedLanguage = lang.id
            }
        } label: {
            HStack(spacing: 10) {
                Text(lang.flag)
                    .font(.title2)
                Text(lang.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected
                          ? Color(hex: "FF2D78").opacity(0.25)
                          : Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color(hex: "FF2D78") : Color.white.opacity(0.1), lineWidth: 1.5)
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Direction Button
    private func directionButton(_ direction: ReaderDirection) -> some View {
        let isSelected = selectedDirection == direction
        let icon: String = {
            switch direction {
            case .rtl: return "arrow.left"
            case .ltr: return "arrow.right"
            case .vertical: return "arrow.down"
            }
        }()
        let subtitle: String = {
            switch direction {
            case .rtl: return "Manga style – swipe right to advance"
            case .ltr: return "Western style – swipe left to advance"
            case .vertical: return "Webtoon style – scroll down"
            }
        }()
        
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedDirection = direction
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color(hex: "FF2D78").opacity(0.2) : Color.white.opacity(0.06))
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(isSelected ? Color(hex: "FF2D78") : .white.opacity(0.5))
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(direction.rawValue)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.4))
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color(hex: "FF2D78"))
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected
                          ? Color(hex: "FF2D78").opacity(0.12)
                          : Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color(hex: "FF2D78").opacity(0.6) : Color.white.opacity(0.08), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Bottom Buttons
    private var bottomButtons: some View {
        HStack(spacing: 16) {
            // Back button (only on step 2)
            if currentStep > 0 {
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        currentStep -= 1
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.body.weight(.medium))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.06))
                    )
                }
                .buttonStyle(PressedScaleButtonStyle())
                .transition(.move(edge: .leading).combined(with: .opacity))
            }
            
            // Next / Get Started button
            Button {
                if currentStep == 0 {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        currentStep = 1
                    }
                } else {
                    completeOnboarding()
                }
            } label: {
                HStack(spacing: 8) {
                    Text(currentStep == 0 ? "Next" : "Get Started")
                        .font(.body.weight(.bold))
                    Image(systemName: currentStep == 0 ? "chevron.right" : "arrow.right")
                        .font(.body.weight(.semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "FF2D78"), Color(hex: "E91E63")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: Color(hex: "FF2D78").opacity(0.4), radius: 12, y: 4)
            }
            .buttonStyle(PressedScaleButtonStyle())
        }
        .padding(.horizontal, 4)
    }
    
    // MARK: - Complete Onboarding
    private func completeOnboarding() {
        settings.preferredLanguage = selectedLanguage
        settings.readerDirection = selectedDirection
        settings.hasCompletedOnboarding = true
        settings.save()
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    OnboardingView()
        .environmentObject(SettingsManager.shared)
}
