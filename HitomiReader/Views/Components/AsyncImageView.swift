// AsyncImageView.swift
// HitomiReader
//
// Custom async image loader that sends the required Referer header
// for hitomi.la image requests. Includes an in-memory NSCache,
// placeholder shimmer, and graceful error handling.

import SwiftUI
import Combine

// MARK: - Image Cache

final class ImageCache {
    static let shared = ImageCache()
    
    private let cache = NSCache<NSURL, UIImage>()
    
    private init() {
        // Allow up to ~200 MB of cached images
        cache.totalCostLimit = 200 * 1024 * 1024
        cache.countLimit = 300
    }
    
    func image(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }
    
    func store(_ image: UIImage, for url: URL) {
        let cost = image.jpegData(compressionQuality: 1.0)?.count ?? 0
        cache.setObject(image, forKey: url as NSURL, cost: cost)
    }
}

// MARK: - Image Loader

@MainActor
final class AsyncImageLoader: ObservableObject {
    @Published var image: UIImage?
    @Published var isLoading = false
    @Published var hasError = false
    
    private var currentURL: URL?
    private var task: Task<Void, Never>?
    
    /// Shared URLSession with Referer header
    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = [
            "Referer": "https://hitomi.la/"
        ]
        config.urlCache = URLCache(
            memoryCapacity: 50 * 1024 * 1024,
            diskCapacity: 200 * 1024 * 1024
        )
        return URLSession(configuration: config)
    }()
    
    func load(url: URL) {
        // Don't reload if already showing this URL
        guard url != currentURL else { return }
        cancel()
        currentURL = url
        
        // Check cache first
        if let cached = ImageCache.shared.image(for: url) {
            self.image = cached
            self.isLoading = false
            self.hasError = false
            return
        }
        
        isLoading = true
        hasError = false
        
        task = Task { [weak self] in
            do {
                let (data, response) = try await AsyncImageLoader.session.data(from: url)
                
                guard !Task.isCancelled else { return }
                
                // Validate HTTP response
                if let httpResponse = response as? HTTPURLResponse,
                   !(200...299).contains(httpResponse.statusCode) {
                    self?.isLoading = false
                    self?.hasError = true
                    return
                }
                
                if let uiImage = UIImage(data: data) {
                    ImageCache.shared.store(uiImage, for: url)
                    self?.image = uiImage
                    self?.isLoading = false
                } else {
                    self?.isLoading = false
                    self?.hasError = true
                }
            } catch {
                guard !Task.isCancelled else { return }
                self?.isLoading = false
                self?.hasError = true
            }
        }
    }
    
    func cancel() {
        task?.cancel()
        task = nil
        currentURL = nil
    }
}

// MARK: - Async Image View

struct AsyncImageView: View {
    let url: URL?
    var contentMode: ContentMode = .fill
    var cornerRadius: CGFloat = 0
    
    @StateObject private var loader = AsyncImageLoader()
    @State private var appeared = false
    
    var body: some View {
        Group {
            if let image = loader.image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .opacity(appeared ? 1 : 0)
                    .scaleEffect(appeared ? 1.0 : 0.96)
                    .onAppear {
                        withAnimation(.easeOut(duration: 0.35)) {
                            appeared = true
                        }
                    }
                    .id(url)
            } else if loader.hasError {
                errorPlaceholder
            } else {
                shimmerPlaceholder
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .onAppear {
            if let url = url {
                loader.load(url: url)
            }
        }
        .onDisappear {
            // Keep cache but cancel pending requests
        }
        .onChange(of: url) { newURL in
            appeared = false
            if let newURL = newURL {
                loader.load(url: newURL)
            }
        }
    }
    
    // MARK: - Shimmer Placeholder
    private var shimmerPlaceholder: some View {
        ShimmerView()
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
    
    // MARK: - Error Placeholder
    private var errorPlaceholder: some View {
        ZStack {
            Color(hex: "1A1A2E")
            VStack(spacing: 8) {
                Image(systemName: "photo.badge.exclamationmark")
                    .font(.title2)
                    .foregroundColor(.white.opacity(0.3))
                Text("Failed to load")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.2))
            }
        }
    }
}

// MARK: - Shimmer Effect

struct ShimmerView: View {
    @State private var phase: CGFloat = -1.0
    
    var body: some View {
        GeometryReader { geometry in
            Color(hex: "1A1A2E")
                .overlay(
                    LinearGradient(
                        colors: [
                            .clear,
                            Color.white.opacity(0.05),
                            Color.white.opacity(0.1),
                            Color.white.opacity(0.05),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 0.6)
                    .offset(x: geometry.size.width * phase)
                )
                .clipped()
        }
        .onAppear {
            withAnimation(
                .linear(duration: 1.5)
                .repeatForever(autoreverses: false)
            ) {
                phase = 1.5
            }
        }
    }
}

#Preview {
    VStack {
        AsyncImageView(
            url: URL(string: "https://example.com/test.jpg"),
            cornerRadius: 12
        )
        .frame(width: 200, height: 280)
    }
    .preferredColorScheme(.dark)
}
