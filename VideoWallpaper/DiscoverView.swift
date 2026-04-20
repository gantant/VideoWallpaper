//
//  DiscoverView.swift
//  VideoWallpaper
//
//  Created by Grant Wilson on 4/19/26.
//


// ============================================================
// DiscoverView.swift
// Browse and download curated free wallpaper videos.
// ============================================================

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Data

struct WallpaperItem: Identifiable {
    let id = UUID()
    let name: String
    let videoURL: String
    let thumbURL: String
}

let discoverItems: [(category: String, items: [WallpaperItem])] = [
    ("Nature", [
        WallpaperItem(name: "Coming Soon", videoURL: "", thumbURL: ""),
        WallpaperItem(name: "Coming Soon", videoURL: "", thumbURL: ""),
        WallpaperItem(name: "Coming Soon", videoURL: "", thumbURL: ""),
    ]),
    ("City", [
        WallpaperItem(name: "Coming Soon", videoURL: "", thumbURL: ""),
        WallpaperItem(name: "Coming Soon", videoURL: "", thumbURL: ""),
        WallpaperItem(name: "Coming Soon", videoURL: "", thumbURL: ""),
    ]),
    ("Abstract", [
        WallpaperItem(
            name: "Abstract 1",
            videoURL: "https://www.pexels.com/download/video/28561594/",
            thumbURL: "https://images.pexels.com/videos/28561594/3d-rendering-abstract-ai-animation-28561594.jpeg"
        ),
        WallpaperItem(
            name: "Abstract 2",
            videoURL: "https://www.pexels.com/download/video/32399542/",
            thumbURL: "https://intelloai.com/hero-intello-poster.jpg"
        ),
        WallpaperItem(
            name: "Abstract 3",
            videoURL: "https://www.pexels.com/download/video/30090680/",
            thumbURL: "https://images.pexels.com/videos/30090680/pexels-photo-30090680.jpeg?auto=compress&cs=tinysrgb&dpr=1&w=500"
        ),
        WallpaperItem(
            name: "Abstract 4",
            videoURL: "https://www.pexels.com/download/video/29460403/",
            thumbURL: "https://images.pexels.com/videos/29460403/3d-abstract-architecture-background-29460403.jpeg?auto=compress&cs=tinysrgb&dpr=1&w=500"
        ),
        WallpaperItem(
            name: "Abstract 5",
            videoURL: "https://www.pexels.com/download/video/8733062/",
            thumbURL: "https://i.ytimg.com/vi/7DCY3faeJUc/maxresdefault.jpg"
        ),
    ]),
    ("Space", [
        WallpaperItem(name: "Coming Soon", videoURL: "", thumbURL: ""),
        WallpaperItem(name: "Coming Soon", videoURL: "", thumbURL: ""),
        WallpaperItem(name: "Coming Soon", videoURL: "", thumbURL: ""),
    ]),
    ("Water", [
        WallpaperItem(name: "Coming Soon", videoURL: "", thumbURL: ""),
        WallpaperItem(name: "Coming Soon", videoURL: "", thumbURL: ""),
        WallpaperItem(name: "Coming Soon", videoURL: "", thumbURL: ""),
    ]),
]

// MARK: - View

struct DiscoverView: View {
    @ObservedObject var vm: WallpaperViewModel
    @Binding var showingDiscover: Bool

    @State private var selectedCategory = "Abstract"
    @State private var loadingID: UUID?
    @State private var isSearching = false
    @State private var searchText = ""

    private let categories = discoverItems.map { $0.category }
    private var currentItems: [WallpaperItem] {
        discoverItems.first { $0.category == selectedCategory }?.items ?? []
    }

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Button { showingDiscover = false } label: {
                    Image(systemName: "arrow.left").foregroundStyle(.white)
                }.buttonStyle(.plain)
                Text("Discover").foregroundStyle(.white).font(.headline)
                Spacer()
                Button { isSearching = true } label: {
                    Image(systemName: "magnifyingglass")
                        .frame(width: 28, height: 28)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                        .foregroundStyle(.white)
                }.buttonStyle(.plain)
            }

            // Inline search bar
            if isSearching {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.gray).font(.caption)
                    TextField("Search Pexels videos…", text: $searchText)
                        .textFieldStyle(.plain).font(.caption).foregroundStyle(.white)
                        .onSubmit { submitSearch() }
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.gray)
                        }.buttonStyle(.plain)
                    }
                    Button("Go") { submitSearch() }
                        .font(.caption.weight(.semibold)).foregroundStyle(.purple).buttonStyle(.plain)
                    Button { isSearching = false; searchText = "" } label: {
                        Text("Cancel").font(.caption).foregroundStyle(.gray)
                    }.buttonStyle(.plain)
                }
                .padding(.horizontal, 10).padding(.vertical, 7)
                .background(Color.white.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // Category pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(categories, id: \.self) { cat in
                        Button { selectedCategory = cat } label: {
                            Text(cat)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(RoundedRectangle(cornerRadius: 20)
                                    .fill(selectedCategory == cat
                                          ? Color.purple.opacity(0.6)
                                          : Color.white.opacity(0.08)))
                                .foregroundStyle(.white)
                        }.buttonStyle(.plain)
                    }
                }
            }

            // Grid
            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 10
                ) {
                    ForEach(currentItems) { item in
                        VStack(spacing: 6) {
                            AsyncImage(url: URL(string: item.thumbURL)) { phase in
                                switch phase {
                                case .success(let img): img.resizable().scaledToFill()
                                case .failure:          Color.red.opacity(0.2)
                                default:                Color.gray.opacity(0.2).overlay(ProgressView())
                                }
                            }
                            .frame(height: 75)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .clipped()

                            Text(item.name)
                                .font(.caption2.weight(.medium)).foregroundStyle(.white).lineLimit(1)

                            Button { downloadAndApply(item) } label: {
                                Group {
                                    if loadingID == item.id {
                                        HStack(spacing: 4) {
                                            ProgressView().scaleEffect(0.6)
                                            Text("Loading…")
                                        }
                                    } else {
                                        Label(
                                            item.videoURL.isEmpty ? "Coming Soon" : "Use",
                                            systemImage: item.videoURL.isEmpty ? "clock" : "play.rectangle.fill"
                                        )
                                    }
                                }
                                .font(.caption2.weight(.semibold))
                                .frame(maxWidth: .infinity).padding(.vertical, 5)
                                .background(RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.purple.opacity(item.videoURL.isEmpty ? 0.15 : 0.4)))
                                .foregroundStyle(.white)
                            }
                            .buttonStyle(.plain)
                            .disabled(loadingID != nil || item.videoURL.isEmpty)
                        }
                        .padding(8).background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
        .padding(16)
    }

    // MARK: - Actions

    private func submitSearch() {
        let q = searchText.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }
        let enc = q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? q
        if let url = URL(string: "https://www.pexels.com/search/videos/\(enc)/") {
            NSWorkspace.shared.open(url)
        }
        isSearching = false; searchText = ""
    }

    private func downloadAndApply(_ item: WallpaperItem) {
        guard !item.videoURL.isEmpty, let url = URL(string: item.videoURL) else { return }
        loadingID = item.id

        let safeFileName = item.name.replacingOccurrences(of: " ", with: "-") + ".mp4"
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            let destDir = (downloads ?? FileManager.default.temporaryDirectory)
                .appendingPathComponent("VideoWallpapers", conformingTo: .directory)            .appendingPathComponent("VideoWallpapers")
        let dest = destDir.appendingPathComponent(safeFileName)

        if FileManager.default.fileExists(atPath: dest.path) {
            loadingID = nil
            vm.selectedURL = dest; vm.applyWallpaper()
            vm.addCurrentToCollection(); showingDiscover = false
            return
        }

        var req = URLRequest(url: url)
        req.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )
        req.setValue("https://www.pexels.com/", forHTTPHeaderField: "Referer")

        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        config.timeoutIntervalForRequest = 60

        URLSession(configuration: config).dataTask(with: req) { data, response, err in
            DispatchQueue.main.async { loadingID = nil }

            if let err { print("[Discover] Error:", err); return }
            guard let data, data.count > 1_000_000 else {
                print("[Discover] Response too small or empty"); return
            }

            do {
                try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
                try? FileManager.default.removeItem(at: dest)
                try data.write(to: dest, options: [.atomic])
                DispatchQueue.main.async {
                    vm.selectedURL = dest; vm.applyWallpaper()
                    vm.addCurrentToCollection(); showingDiscover = false
                }
            } catch {
                print("[Discover] Write error:", error)
            }
        }.resume()
    }
}

