// ReaderView.swift
// HitomiReader
//
// Full-screen image reader with RTL (manga), LTR, and vertical scroll modes.
// Features: tap-to-navigate, pinch-to-zoom, page preloading, overlay toggle,
// and automatic history/progress saving.

import SwiftUI

struct ReaderView: View {
    let gallery: Gallery
    let startPage: Int
    
    @EnvironmentObject var settings: SettingsManager
    @EnvironmentObject var history: HistoryManager
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - State
    @State private var currentPage: Int = 0
    @State private var showOverlay = false
    @State private var imageURLs: [Int: URL] = [:]
    @State private var isLoadingURLs = true
    
    // Zoom state
    @State private var currentZoom: CGFloat = 1.0
    @State private var totalZoom: CGFloat = 1.0
    
    private var pageCount: Int { gallery.files?.count ?? 0 }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if isLoadingURLs {
                loadingOverlay
            } else {
                readerContent
            }
            
            // MARK: - UI Overlay
            if showOverlay {
                overlayUI
            }
        }
        .statusBar(hidden: !showOverlay)
        .persistentSystemOverlays(.hidden)
        .onAppear {
            currentPage = startPage
            Task { await resolveImageURLs() }
        }
        .onChange(of: currentPage) { newPage in
            saveProgress(page: newPage)
        }
        .gesture(
            TapGesture()
                .onEnded {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showOverlay.toggle()
                    }
                }
        )
    }
    
    // MARK: - Reader Content (Direction Switch)
    @ViewBuilder
    private var readerContent: some View {
        switch settings.readerDirection {
        case .rtl:
            rtlReader
        case .ltr:
            ltrReader
        case .vertical:
            verticalReader
        }
    }
    
    // MARK: - RTL Reader (Manga Style)
    private var rtlReader: some View {
        TabView(selection: $currentPage) {
            ForEach(0..<pageCount, id: \.self) { index in
                pageView(index: index)
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .environment(\.layoutDirection, .rightToLeft)
        .ignoresSafeArea()
    }
    
    // MARK: - LTR Reader (Western Style)
    private var ltrReader: some View {
        TabView(selection: $currentPage) {
            ForEach(0..<pageCount, id: \.self) { index in
                pageView(index: index)
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .ignoresSafeArea()
    }
    
    // MARK: - Vertical Reader (Webtoon Style)
    private var verticalReader: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(0..<pageCount, id: \.self) { index in
                        pageView(index: index)
                            .id(index)
                            .frame(maxWidth: .infinity)
                            .onAppear {
                                currentPage = index
                            }
                    }
                }
            }
            .ignoresSafeArea()
            .onAppear {
                if startPage > 0 {
                    proxy.scrollTo(startPage, anchor: .top)
                }
            }
        }
    }
    
    // MARK: - Page View
    private func pageView(index: Int) -> some View {
        ZStack {
            Color.black
            
            if let url = imageURLs[index] {
                ZoomableImageView(url: url)
            } else {
                // Try to resolve URL on-the-fly
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(.white.opacity(0.5))
                    Text("Loading page \(index + 1)…")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.3))
                }
                .task {
                    await resolveURL(for: index)
                }
            }
        }
        .task {
            // Preload adjacent pages
            await preloadAdjacentPages(around: index)
        }
    }
    
    // MARK: - Zoomable Image View
    struct ZoomableImageView: View {
        let url: URL
        
        @State private var scale: CGFloat = 1.0
        @State private var lastScale: CGFloat = 1.0
        @State private var offset: CGSize = .zero
        @State private var lastOffset: CGSize = .zero
        
        var body: some View {
            AsyncImageView(url: url, contentMode: .fit, cornerRadius: 0)
                .scaleEffect(scale)
                .offset(offset)
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            let delta = value / lastScale
                            lastScale = value
                            scale = min(max(scale * delta, 1.0), 5.0)
                        }
                        .onEnded { _ in
                            lastScale = 1.0
                            if scale < 1.1 {
                                withAnimation(.spring(response: 0.3)) {
                                    scale = 1.0
                                    offset = .zero
                                }
                            }
                        }
                )
                .simultaneousGesture(
                    DragGesture()
                        .onChanged { value in
                            guard scale > 1.05 else { return }
                            offset = CGSize(
                                width: lastOffset.width + value.translation.width,
                                height: lastOffset.height + value.translation.height
                            )
                        }
                        .onEnded { _ in
                            guard scale > 1.05 else { return }
                            lastOffset = offset
                        }
                )
                .onTapGesture(count: 2) {
                    withAnimation(.spring(response: 0.3)) {
                        if scale > 1.1 {
                            scale = 1.0
                            offset = .zero
                            lastOffset = .zero
                        } else {
                            scale = 2.5
                        }
                    }
                }
        }
    }
    
    // MARK: - Overlay UI
    private var overlayUI: some View {
        VStack {
            // Top bar
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.8))
                        .symbolRenderingMode(.hierarchical)
                }
                
                Spacer()
                
                Text(gallery.japaneseTitle ?? gallery.title)
                    .font(.caption.weight(.medium))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
                
                Spacer()
                
                // Direction indicator
                directionBadge
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .background(
                LinearGradient(
                    colors: [Color.black.opacity(0.8), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            
            Spacer()
            
            // Bottom bar
            VStack(spacing: 12) {
                // Page slider
                if settings.readerDirection != .vertical {
                    pageSlider
                }
                
                // Page indicator
                Text("Page \(currentPage + 1) / \(pageCount)")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .environment(\.colorScheme, .dark)
                    )
            }
            .padding(.bottom, 20)
            .padding(.horizontal, 20)
            .background(
                LinearGradient(
                    colors: [.clear, Color.black.opacity(0.8)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
        }
        .transition(.opacity)
    }
    
    // MARK: - Page Slider
    private var pageSlider: some View {
        HStack(spacing: 12) {
            Text("\(settings.readerDirection == .rtl ? pageCount : 1)")
                .font(.caption2.monospacedDigit())
                .foregroundColor(.white.opacity(0.5))
            
            Slider(
                value: Binding<Double>(
                    get: { Double(currentPage) },
                    set: { currentPage = Int($0) }
                ),
                in: 0...Double(max(0, pageCount - 1)),
                step: 1
            )
            .tint(Color(hex: "FF2D78"))
            
            Text("\(settings.readerDirection == .rtl ? 1 : pageCount)")
                .font(.caption2.monospacedDigit())
                .foregroundColor(.white.opacity(0.5))
        }
    }
    
    // MARK: - Direction Badge
    private var directionBadge: some View {
        let icon: String = {
            switch settings.readerDirection {
            case .rtl: return "arrow.left"
            case .ltr: return "arrow.right"
            case .vertical: return "arrow.down"
            }
        }()
        
        return Image(systemName: icon)
            .font(.caption.weight(.semibold))
            .foregroundColor(.white.opacity(0.5))
            .frame(width: 30, height: 30)
            .background(Circle().fill(.ultraThinMaterial).environment(\.colorScheme, .dark))
    }
    
    // MARK: - Loading Overlay
    private var loadingOverlay: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(Color(hex: "FF2D78"))
            Text("Preparing reader…")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.5))
        }
    }
    
    // MARK: - URL Resolution
    
    private func resolveImageURLs() async {
        do {
            try await ImageURLResolver.shared.ensureReady()
        } catch {
            // Continue anyway, will try per-page
        }
        
        // Resolve first few pages immediately + current page
        let priorityPages = Array(Set([startPage] + Array(0..<min(5, pageCount))))
        for index in priorityPages {
            await resolveURL(for: index)
        }
        
        isLoadingURLs = false
        
        // Resolve remaining in background
        for index in 0..<pageCount where imageURLs[index] == nil {
            await resolveURL(for: index)
        }
    }
    
    private func resolveURL(for index: Int) async {
        guard index >= 0, index < pageCount, imageURLs[index] == nil else { return }
        guard let files = gallery.files, index < files.count else { return }
        let image = files[index]
        if let url = try? await HitomiAPI.shared.getImageURL(image: image, galleryID: gallery.id) {
            imageURLs[index] = url
        }
    }
    
    private func preloadAdjacentPages(around index: Int) async {
        let range = max(0, index - 2)...min(pageCount - 1, index + 2)
        for i in range {
            await resolveURL(for: i)
        }
    }
    
    // MARK: - Save Progress
    
    private func saveProgress(page: Int) {
        var thumbnailURL: URL? = nil
        if let firstImage = gallery.files?.first {
            thumbnailURL = try? ImageURLResolver.shared.resolveThumbnailURL(galleryID: gallery.id, image: firstImage)
        }
        history.upsert(
            galleryID: gallery.id,
            title: gallery.displayTitle,
            thumbnailURL: thumbnailURL,
            lastPage: page,
            totalPages: pageCount
        )
    }
}

#Preview {
    ReaderView(
        gallery: Gallery(
            id: 12345,
            title: "Sample Gallery",
            japaneseTitle: nil,
            artists: [],
            groups: [],
            parodys: [],
            tags: [],
            characters: [],
            language: "english",
            languageLocalname: "English",
            type: "manga",
            date: nil,
            files: [
                GalleryImage(name: "001.jpg", hash: "abc123def456", width: 1200, height: 1700, haswebp: 1, hasavif: 0, hasjxl: 0),
                GalleryImage(name: "002.jpg", hash: "def456ghi789", width: 1200, height: 1700, haswebp: 1, hasavif: 0, hasjxl: 0)
            ]
        ),
        startPage: 0
    )
    .environmentObject(SettingsManager.shared)
    .environmentObject(HistoryManager.shared)
    .preferredColorScheme(.dark)
}
