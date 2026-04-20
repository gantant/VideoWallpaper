// ============================================================
// CollectionView.swift
// ============================================================

import SwiftUI

struct CollectionView: View {
    @ObservedObject var vm: WallpaperViewModel
    @Binding var showingCollection: Bool

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button { showingCollection = false } label: {
                    Image(systemName: "arrow.left").foregroundStyle(.white)
                }.buttonStyle(.plain)
                Text("My Library").foregroundStyle(.white).font(.headline)
                Spacer()
            }

            if vm.savedWallpapers.isEmpty {
                Spacer()
                Text("Your library is empty.\nAdd videos from the main screen.")
                    .multilineTextAlignment(.center).font(.caption).foregroundStyle(.gray)
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.flexible()), GridItem(.flexible())],
                        spacing: 10
                    ) {
                        ForEach(vm.savedWallpapers, id: \.self) { url in
                            CollectionItemView(
                                url: url, vm: vm,
                                showingCollection: $showingCollection
                            )
                        }
                    }
                }
            }
        }
        .padding(16)
    }
}

// MARK: - Collection Item

struct CollectionItemView: View {
    let url: URL
    @ObservedObject var vm: WallpaperViewModel
    @Binding var showingCollection: Bool
    @State private var showingInfo = false
    @State private var videoInfo: VideoInfo?

    var body: some View {
        VStack(spacing: 4) {
            ThumbnailView(url: url)
                .frame(height: 75)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Text(url.lastPathComponent)
                .font(.caption2).foregroundStyle(.white).lineLimit(1)

            HStack(spacing: 12) {
                Button {
                    vm.selectFromCollection(url)
                    showingCollection = false
                } label: {
                    Image(systemName: "play.fill").foregroundStyle(.green).font(.caption)
                }.buttonStyle(.plain)

                Button {
                    Task { videoInfo = await VideoInfo.load(from: url); showingInfo = true }
                } label: {
                    Image(systemName: "info.circle").foregroundStyle(.blue).font(.caption)
                }.buttonStyle(.plain)

                Button { vm.removeFromCollection(url) } label: {
                    Image(systemName: "trash").foregroundStyle(.red.opacity(0.7)).font(.caption)
                }.buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contextMenu {
            Button("Set as Wallpaper") {
                vm.selectFromCollection(url); showingCollection = false
            }
            Button("Get Info") {
                Task { videoInfo = await VideoInfo.load(from: url); showingInfo = true }
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