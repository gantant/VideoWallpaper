//
//  CollectionView.swift
//  VideoWallpaper
//
//  Created by Grant Wilson on 4/19/26.
//


// ============================================================
// CollectionView.swift
// ============================================================

import SwiftUI

struct CollectionView: View {
    @ObservedObject var vm: WallpaperViewModel
    @Binding var showingCollection: Bool
    @AppStorage("liquidGlass") private var liquidGlass = false
    @AppStorage("accentHex") private var accentHex: String = "8B5CF6"

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                BackNavigationButton(title: "Back") { showingCollection = false }
                Text("My Library").foregroundStyle(.white).font(.headline)
                Spacer()
                if !vm.savedWallpapers.isEmpty {
                    Text("\(vm.savedWallpapers.count) video\(vm.savedWallpapers.count == 1 ? "" : "s")")
                        .font(.caption2).foregroundStyle(.gray)
                }
            }

            if vm.savedWallpapers.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "film.stack").font(.system(size: 32)).foregroundStyle(.gray)
                    Text("Your library is empty.\nAdd videos from the main screen.")
                        .multilineTextAlignment(.center).font(.caption).foregroundStyle(.gray)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.flexible()), GridItem(.flexible())],
                        spacing: 10
                    ) {
                        // Use sortedWallpapers so favorites appear first,
                        // and bind removal directly so UI updates immediately.
                        ForEach(vm.sortedWallpapers, id: \.self) { url in
                            CollectionItemView(
                                url: url,
                                vm: vm,
                                showingCollection: $showingCollection
                            )
                        }
                    }
                }
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
}

// MARK: - Collection Item

struct CollectionItemView: View {
    let url: URL
    @ObservedObject var vm: WallpaperViewModel
    @Binding var showingCollection: Bool

    @State private var showingInfo = false
    @State private var videoInfo: VideoInfo?
    @State private var isLoadingInfo = false

    var isFav: Bool { vm.isFavorited(url) }
    @AppStorage("accentHex") private var accentHex: String = "8B5CF6"
    @AppStorage("liquidGlass") private var liquidGlass = false

    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                ThumbnailView(url: url)
                    .frame(height: 75)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                // Favorite badge
                Button {
                    vm.toggleFavorite(url)
                } label: {
                    Image(systemName: isFav ? "star.fill" : "star")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(isFav ? .yellow : .white.opacity(0.7))
                        .padding(4)
                        .background(.black.opacity(0.4))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .padding(4)
            }

            Text(url.lastPathComponent)
                .font(.caption2).foregroundStyle(.white).lineLimit(1)

            HStack(spacing: 10) {
                Button {
                    vm.selectFromCollection(url)
                    showingCollection = false
                } label: {
                    Image(systemName: "play.fill").foregroundStyle(.green).font(.caption)
                }.buttonStyle(.plain)

                Button {
                    guard !isLoadingInfo else { return }
                    isLoadingInfo = true
                    Task {
                        let info = await VideoInfo.load(from: url)
                        await MainActor.run {
                            videoInfo = info
                            isLoadingInfo = false
                            showingInfo = true
                        }
                    }
                } label: {
                    if isLoadingInfo {
                        ProgressView().scaleEffect(0.5).frame(width: 12, height: 12)
                    } else {
                        Image(systemName: "info.circle").foregroundStyle(.blue).font(.caption)
                    }
                }.buttonStyle(.plain)

                // Trash — calls removeFromCollection which fires objectWillChange
                // immediately, so the grid updates without needing to leave the view.
                Button {
                    vm.removeFromCollection(url)
                } label: {
                    Image(systemName: "trash").foregroundStyle(.red.opacity(0.7)).font(.caption)
                }.buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(LiquidCardBackground(cornerRadius: 8, tint: Color(hex: accentHex), liquidGlass: liquidGlass))
        .overlay(
            ZStack {
                if isFav {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.yellow.opacity(0.4), lineWidth: 1)
                }
                if vm.selectedURL == url {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(hex: accentHex).opacity(0.6), lineWidth: 2)
                }
            }
        )
        .contextMenu {
            Button("Set as Wallpaper") {
                vm.selectFromCollection(url); showingCollection = false
            }
            Button(isFav ? "Unfavorite" : "Favorite") {
                vm.toggleFavorite(url)
            }
            Button("Get Info") {
                Task {
                    let info = await VideoInfo.load(from: url)
                    await MainActor.run { videoInfo = info; showingInfo = true }
                }
            }
            Divider()
            Button("Reveal in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
            Divider()
            Button("Remove from Library", role: .destructive) {
                vm.removeFromCollection(url)
            }
        }
        .sheet(isPresented: $showingInfo) {
            if let info = videoInfo {
                VideoInfoSheet(url: url, info: info, isPresented: $showingInfo)
                    .preferredColorScheme(.dark)
            }
        }
    }
}

