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

// MARK: - View

struct DiscoverView: View {
    @ObservedObject var vm: WallpaperViewModel
    @Binding var showingDiscover: Bool

    @AppStorage("liquidGlass") private var liquidGlass = false
    @AppStorage("accentHex") private var accentHex: String = "8B5CF6"
    @AppStorage("discoverSort") private var discoverSort: String = "featured"

    @State private var selectedCategory = "Featured"
    @State private var loadingID: String?
    @State private var isSearching = false
    @State private var searchText = ""
    @State private var errorText: String?
    @State private var sourceFilter = "All Sources"

    private var categories: [String] { DiscoverCatalog.categories }
    private var sources: [String] {
        ["All Sources"] + Array(Set(DiscoverCatalog.items.map(\.sourceName))).sorted()
    }
    private var currentItems: [WallpaperItem] {
        var list = DiscoverCatalog.items.filter { selectedCategory == "Featured" || $0.category == selectedCategory }

        if sourceFilter != "All Sources" {
            list = list.filter { $0.sourceName == sourceFilter }
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !query.isEmpty {
            list = list.filter { item in
                item.name.lowercased().contains(query)
                || item.genre.lowercased().contains(query)
                || item.tags.joined(separator: " ").lowercased().contains(query)
            }
        }

        switch discoverSort {
        case "name":
            return list.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case "source":
            return list.sorted {
                if $0.sourceName == $1.sourceName {
                    return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                }
                return $0.sourceName.localizedCaseInsensitiveCompare($1.sourceName) == .orderedAscending
            }
        default:
            return list.sorted { $0.isAvailable && !$1.isAvailable }
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            headerView

            if isSearching {
                searchBar
            }

            sourceAndSortRow
            categoriesStrip

            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 10
                ) {
                    ForEach(currentItems) { item in
                        card(for: item)
                    }
                }
            }

            if let errorText {
                Text(errorText)
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
        .padding(16)
        .background(
            Group {
                if liquidGlass, #available(macOS 26, *) {
                    Color.clear
                } else {
                    Color(red: 0.08, green: 0.08, blue: 0.10)
                }
            }
        )
    }

    // MARK: - Actions

    private var headerView: some View {
        HStack {
            Text("Discover").foregroundStyle(.white).font(.headline)
            Spacer()
            Button { isSearching = true } label: {
                Image(systemName: "magnifyingglass")
                    .frame(width: 28, height: 28)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.gray).font(.caption)
            TextField("Search by name, genre, or tags…", text: $searchText)
                .textFieldStyle(.plain).font(.caption).foregroundStyle(.white)
                .onSubmit { submitSearch() }
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.gray)
                }.buttonStyle(.plain)
            }
            Button("Web") { submitSearch() }
                .font(.caption.weight(.semibold)).foregroundStyle(Color(hex: accentHex)).buttonStyle(.plain)
            Button { isSearching = false; searchText = "" } label: {
                Text("Cancel").font(.caption).foregroundStyle(.gray)
            }.buttonStyle(.plain)
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var sourceAndSortRow: some View {
        HStack(spacing: 8) {
            Picker("", selection: $sourceFilter) {
                ForEach(sources, id: \.self) { src in
                    Text(src).tag(src)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)

            Picker("", selection: $discoverSort) {
                Text("Featured").tag("featured")
                Text("Name").tag("name")
                Text("Source").tag("source")
            }
            .labelsHidden()
            .pickerStyle(.menu)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var categoriesStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(categories, id: \.self) { cat in
                    categoryPill(cat)
                }
            }
        }
    }

    private func categoryPill(_ category: String) -> some View {
        Button { selectedCategory = category } label: {
            Text(category)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(selectedCategory == category ? Color(hex: accentHex).opacity(0.6) : Color.white.opacity(0.08))
                )
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }

    private func card(for item: WallpaperItem) -> some View {
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

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text("\(item.genre) • \(item.sourceName)")
                        .font(.system(size: 10))
                        .foregroundStyle(.gray)
                        .lineLimit(1)
                }
                Spacer()
            }

            Button { downloadAndApply(item) } label: {
                Group {
                    if loadingID == item.id {
                        HStack(spacing: 4) {
                            ProgressView().scaleEffect(0.6)
                            Text("Loading…")
                        }
                    } else {
                        Label(
                            item.isAvailable ? "Use" : "Open Source",
                            systemImage: item.isAvailable ? "play.rectangle.fill" : "safari"
                        )
                    }
                }
                .font(.caption2.weight(.semibold))
                .frame(maxWidth: .infinity).padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color(hex: accentHex).opacity(item.isAvailable ? 0.4 : 0.2)))
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .disabled(loadingID != nil)
            .contextMenu {
                Button("Open Source Page") { openSourcePage(item) }
                if item.isAvailable {
                    Button("Copy Video URL") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(item.videoURL, forType: .string)
                    }
                }
            }
        }
        .padding(8)
        .background(LiquidCardBackground(cornerRadius: 8, tint: Color(hex: accentHex), liquidGlass: liquidGlass))
    }

    private func submitSearch() {
        let q = searchText.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }
        let enc = q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? q
        if let url = URL(string: "https://www.pexels.com/search/videos/\(enc)/") {
            NSWorkspace.shared.open(url)
        }
    }

    private func openSourcePage(_ item: WallpaperItem) {
        guard let url = URL(string: item.sourcePageURL) else { return }
        NSWorkspace.shared.open(url)
    }

    private func downloadAndApply(_ item: WallpaperItem) {
        guard item.isAvailable, let url = URL(string: item.videoURL) else {
            openSourcePage(item)
            return
        }
        loadingID = item.id
        errorText = nil

        let safeFileName = item.name.replacingOccurrences(of: " ", with: "-") + ".mp4"
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        let destDir = (downloads ?? FileManager.default.temporaryDirectory)
            .appendingPathComponent("VideoWallpapers", isDirectory: true)
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
                DispatchQueue.main.async {
                    errorText = "Download failed. Try opening the source page."
                }
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

