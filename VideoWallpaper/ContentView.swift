// ============================================================
// ContentView.swift
// ============================================================

import SwiftUI
import AVKit

// MARK: - Live preview (NSViewRepresentable wrapping AVPlayerView)

struct LivePreviewView: NSViewRepresentable {
    class Coordinator {
        var player: AVQueuePlayer?
        var looper: AVPlayerLooper?
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> AVPlayerView {
        let v = AVPlayerView()
        v.controlsStyle = .none
        v.videoGravity = .resizeAspectFill
        return v
    }

    func updateNSView(_ v: AVPlayerView, context: Context) {
        let url = AppState.shared.viewModel.selectedURL ?? WallpaperWindowController.shared.currentURL
        guard let url else {
            v.player = nil
            context.coordinator.player = nil
            context.coordinator.looper = nil
            return
        }

        let player = AVQueuePlayer()
        let item = AVPlayerItem(url: url)
        let looper = AVPlayerLooper(player: player, templateItem: item)

        player.isMuted = true
        player.volume = 0
        player.playImmediately(atRate: WallpaperWindowController.shared.currentRate)

        context.coordinator.player = player
        context.coordinator.looper = looper
        v.player = player
    }
}

// MARK: - Content View

struct ContentView: View {
    @StateObject var vm: WallpaperViewModel = AppState.shared.viewModel
    @StateObject private var updater = GitHubUpdater()

    @State private var showingCollection = false
    @State private var showingSettings   = false
    @State private var showingDiscover   = false
    @State private var showingInfo       = false
    @State private var isLoadingInfo     = false
    @State private var videoInfo: VideoInfo?
    @State private var isDroppingFile    = false

    @AppStorage("liquidGlass") private var liquidGlass = false
    @AppStorage("accentHex")   private var accentHex: String = "8B5CF6"

    private var accent: Color { Color(hex: accentHex) }

    // MARK: Dynamic height
    private var popoverHeight: CGFloat {
        var h: CGFloat = 20 // top padding

        // Header
        h += 70
        // Divider
        h += 17

        if showingSettings {
            return 560 // settings stays fixed
        }
        if showingCollection || showingDiscover {
            return 560
        }

        // Live preview
        if vm.isActive { h += 110 } // preview + gap

        // File pill
        if vm.selectedURL != nil { h += 44 }
        // Choose button
        h += 46
        // Gap
        h += 8

        // Rotation badge
        if vm.isRotating { h += 44 }

        // Grid
        if vm.selectedURL != nil {
            let rows = vm.isActive ? 2 : 1  // 4 buttons = 2 rows, 3 = 2 rows, 2 = 1 row
            h += CGFloat(rows) * 74 + CGFloat(rows - 1) * 10 + 10
        }

        // Status
        h += 24
        // Spacer min
        h += 8
        // Divider + bottom bar
        h += 17 + 46
        // bottom padding
        h += 20

        return max(h, 280)
    }

    var body: some View {
        ZStack {
            if liquidGlass, #available(macOS 26, *) {
                Color.clear.ignoresSafeArea()
            } else {
                Color(red: 0.08, green: 0.08, blue: 0.10).ignoresSafeArea()
            }

            if showingSettings {
                SettingsView(vm: vm, showingSettings: $showingSettings)
            } else if showingCollection {
                CollectionView(vm: vm, showingCollection: $showingCollection)
            } else if showingDiscover {
                DiscoverView(vm: vm, showingDiscover: $showingDiscover)
            } else {
                mainView
            }
        }
        .frame(width: 360, height: popoverHeight)
        .animation(.easeInOut(duration: 0.2), value: popoverHeight)
        .sheet(isPresented: $showingInfo) {
            if let info = videoInfo, let url = vm.selectedURL {
                VideoInfoSheet(url: url, info: info, isPresented: $showingInfo)
                    .preferredColorScheme(.dark)
            }
        }
    }

    // MARK: - Main screen

    private var mainView: some View {
        VStack(spacing: 14) {

            // Header
            ZStack {
                VStack(spacing: 4) {
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 28)).foregroundStyle(accent)
                    Text("Video Wallpaper")
                        .font(.title3.bold()).foregroundStyle(.white)
                    Text("Live video on your desktop")
                        .font(.caption).foregroundStyle(.gray)
                }
                HStack {
                    Spacer()
                    Button { showingDiscover = true } label: {
                        Image(systemName: "sparkles")
                            .frame(width: 32, height: 32)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }.buttonStyle(.plain).foregroundStyle(.white)
                }
            }

            Divider().background(Color.white.opacity(0.1))

            // Live mini-preview
            if vm.isActive {
                ZStack(alignment: .bottomTrailing) {
                    LivePreviewView()
                        .frame(height: 90)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(accent.opacity(0.3), lineWidth: 1)
                        )

                    // Small "live" badge
                    Text("LIVE")
                        .font(.system(size: 8, weight: .black))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(accent.opacity(0.85))
                        .clipShape(Capsule())
                        .padding(6)
                }
            }

            // Drag-and-drop + file picker
            VStack(spacing: 8) {
                if let url = vm.selectedURL {
                    HStack(spacing: 8) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .foregroundStyle(accent).font(.caption)
                        Text(url.lastPathComponent)
                            .foregroundStyle(.white).font(.caption)
                            .lineLimit(1).truncationMode(.middle)
                        Spacer()
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
                                Image(systemName: "info.circle")
                                    .foregroundStyle(.gray).font(.caption)
                            }
                        }.buttonStyle(.plain)

                        Button { vm.selectedURL = nil; vm.removeWallpaper() } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.gray).font(.caption)
                        }.buttonStyle(.plain)
                    }
                    .padding(10)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                // Choose button — doubles as drop target
                Button { vm.browseForVideo() } label: {
                    ZStack {
                        Label(
                            vm.selectedURL == nil ? "Choose a Video File…" : "Swap Video File…",
                            systemImage: "arrow.up.doc.fill"
                        )
                        .frame(maxWidth: .infinity).padding(.vertical, 9)

                        if isDroppingFile {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(accent, lineWidth: 2)
                                .background(accent.opacity(0.1).clipShape(RoundedRectangle(cornerRadius: 8)))
                        }
                    }
                }
                .buttonStyle(DarkButtonStyle(color: accent))
                .onDrop(of: [.fileURL], isTargeted: $isDroppingFile) { providers in
                    guard let provider = providers.first else { return false }
                    _ = provider.loadObject(ofClass: URL.self) { url, _ in
                        guard let url else { return }
                        let validExts = ["mp4", "mov", "m4v", "avi", "mkv"]
                        guard validExts.contains(url.pathExtension.lowercased()) else { return }
                        DispatchQueue.main.async { vm.applyURL(url) }
                    }
                    return true
                }
            }

            // Rotation badge
            if vm.isRotating {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundStyle(.orange).font(.caption)
                    Text("Auto-rotation active")
                        .font(.caption).foregroundStyle(.orange)
                    Spacer()
                    Button { vm.stopRotation() } label: {
                        Text("Stop").font(.caption2.weight(.semibold)).foregroundStyle(.red)
                    }.buttonStyle(.plain)
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // Action grid
            if vm.selectedURL != nil {
                let cols = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
                LazyVGrid(columns: cols, spacing: 10) {
                    gridButton(
                        icon: vm.isCurrentInCollection() ? "checkmark.circle.fill" : "star.circle.fill",
                        label: vm.isCurrentInCollection() ? "In Library" : "Add to Library",
                        color: vm.isCurrentInCollection() ? .gray : accent,
                        disabled: vm.isCurrentInCollection()
                    ) { vm.addCurrentToCollection() }

                    gridButton(
                        icon: vm.isActive ? "arrow.clockwise.circle.fill" : "play.rectangle.fill",
                        label: vm.isActive ? "Restart Wallpaper" : "Set as Wallpaper",
                        color: .green
                    ) { vm.applyWallpaper() }

                    if vm.isActive {
                        gridButton(icon: "stop.circle.fill", label: "Remove Wallpaper",
                                   color: .red.opacity(0.85)) { vm.removeWallpaper() }
                    }

                    gridButton(icon: "books.vertical.fill", label: "My Library", color: .blue) {
                        showingCollection = true
                    }
                }
            }

            // Status
            HStack(spacing: 5) {
                Circle()
                    .fill(vm.isActive ? Color.green : Color.gray)
                    .frame(width: 6, height: 6)
                Text(vm.isActive
                     ? "Active on \(NSScreen.screens.count) display\(NSScreen.screens.count == 1 ? "" : "s")"
                     : "No wallpaper set — or drop a file here")
                    .font(.caption2).foregroundStyle(.gray)
            }

            Spacer()
            Divider().background(Color.white.opacity(0.1))

            // Bottom bar
            HStack(spacing: 8) {
                Button { showingSettings = true } label: {
                    Image(systemName: "gearshape.fill")
                        .frame(width: 36, height: 32)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }.buttonStyle(.plain).foregroundStyle(.white)

                Button {
                    Task { await updater.checkForUpdates(showNoUpdateAlert: true) }
                } label: {
                    Group {
                        if updater.isChecking {
                            Label("Checking…", systemImage: "arrow.trianglehead.2.clockwise")
                        } else {
                            Label("Check Updates", systemImage: "arrow.down.circle")
                        }
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 7)
                }
                .buttonStyle(DarkButtonStyle(color: .blue.opacity(0.5)))
                .disabled(updater.isChecking)

                Button { NSApp.terminate(nil) } label: {
                    Image(systemName: "power")
                        .frame(width: 36, height: 32)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }.buttonStyle(.plain).foregroundStyle(.white)
            }
        }
        .padding(20)
    }

    // MARK: - Grid button helper

    @ViewBuilder
    private func gridButton(
        icon: String, label: String, color: Color,
        disabled: Bool = false, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 18))
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .multilineTextAlignment(.center)
            }.frame(maxWidth: .infinity, minHeight: 58)
        }
        .buttonStyle(GridButtonStyle(color: color, liquidGlass: liquidGlass))
        .disabled(disabled)
    }
}

