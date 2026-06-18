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
    nonisolated private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = [
            "Referer": "https://hitomi.la/",
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1"
        ]
        config.urlCache = URLCache(
            memoryCapacity: 50 * 1024 * 1024,
            diskCapacity: 200 * 1024 * 1024
        )
        return URLSession(configuration: config)
    }()

    /// Preloads an image into the shared cache on a background thread.
    nonisolated static func preload(url: URL) {
        if url.isFileURL { return }
        if ImageCache.shared.image(for: url) != nil {
            return
        }

        Task.detached(priority: .background) {
            do {
                let (data, response) = try await AsyncImageLoader.session.data(from: url)
                if let httpResponse = response as? HTTPURLResponse,
                   (200...299).contains(httpResponse.statusCode),
                   let uiImage = UIImage(data: data) {
                    ImageCache.shared.store(uiImage, for: url)
                }
            } catch {
                // Ignore preloading errors
            }
        }
    }
    
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
                let data: Data
                if url.isFileURL {
                    data = try Data(contentsOf: url)
                } else {
                    let (fetchedData, response) = try await AsyncImageLoader.session.data(from: url)
                    
                    if let httpResponse = response as? HTTPURLResponse,
                       !(200...299).contains(httpResponse.statusCode) {
                        print("[AsyncImageView] HTTP Error \(httpResponse.statusCode) loading \(url.absoluteString)")
                        self?.isLoading = false
                        self?.hasError = true
                        return
                    }
                    data = fetchedData
                }
                
                guard !Task.isCancelled else { return }
                
                if let uiImage = UIImage(data: data) {
                    ImageCache.shared.store(uiImage, for: url)
                    self?.image = uiImage
                    self?.isLoading = false
                } else {
                    print("[AsyncImageView] Failed to decode image data for \(url.absoluteString)")
                    self?.isLoading = false
                    self?.hasError = true
                }
            } catch {
                print("[AsyncImageView] Error loading \(url.absoluteString): \(error.localizedDescription)")
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
        Button {
            if let url = url {
                appeared = false
                loader.load(url: url)
            }
        } label: {
            ZStack {
                Color(hex: "1A1A2E")
                VStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.6))
                    Text("Failed to load. Tap to retry.")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))
                }
            }
        }
        .buttonStyle(.plain)
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
