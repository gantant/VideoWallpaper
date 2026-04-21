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
    @State private var pulseColor: Color = .clear
    @State private var pulseScale: CGFloat = 0.15
    @State private var pulseOpacity: Double = 0

    @AppStorage("liquidGlass") private var liquidGlass = false
    @AppStorage("accentHex")   private var accentHex: String = "8B5CF6"
    @AppStorage("buttonRippleFX") private var buttonRippleFX = false

    private var accent: Color { Color(hex: accentHex) }

    /// Narrower than full popover width so the file row, swap control, preview, and bar read as compact tiles.
    private let centeredControlMaxWidth: CGFloat = 278

    private var compactIntroMode: Bool {
        !UserDefaults.standard.bool(forKey: "hasEverChosenVideo")
    }

    private var shuffleDisabled: Bool {
        vm.savedWallpapers.filter { $0 != vm.selectedURL }.isEmpty
    }

    private var actionButtonCount: Int {
        if compactIntroMode { return 2 }
        return 6
    }

    /// Popover is 360pt wide; content area is 320pt after 20pt side padding.
    private var actionGridColumns: [GridItem] {
        let contentWidth: CGFloat = 320
        let spacing: CGFloat = 10
        let colWidth = max(120, floor((contentWidth - spacing) / 2))
        return [
            GridItem(.fixed(colWidth), spacing: spacing, alignment: .center),
            GridItem(.fixed(colWidth), spacing: spacing, alignment: .center)
        ]
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
                    .frame(maxWidth: .infinity, maxHeight: 430, alignment: .top)
            } else if showingCollection {
                CollectionView(vm: vm, showingCollection: $showingCollection)
            } else if showingDiscover {
                DiscoverView(vm: vm, showingDiscover: $showingDiscover)
                    .frame(maxWidth: .infinity, maxHeight: 430, alignment: .top)
            } else {
                mainView
            }

            Circle()
                .fill(pulseColor.opacity(0.55))
                .frame(width: 52, height: 52)
                .scaleEffect(pulseScale)
                .blur(radius: 28)
                .allowsHitTesting(false)
                .opacity(pulseOpacity)
                .blendMode(.plusLighter)
                .zIndex(1000)
        }
        .environment(\.popoverRippleTrigger, { c in triggerPopoverPulse(c) })
        .environment(\.buttonRippleFXEnabled, buttonRippleFX)
        .frame(width: 360)
        .fixedSize(horizontal: false, vertical: true)
        .preferredColorScheme(.dark)
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
            }

            Divider().background(Color.white.opacity(0.1))

            // Live mini-preview
            if vm.isActive {
                HStack {
                    Spacer(minLength: 0)
                    ZStack(alignment: .bottomTrailing) {
                        LivePreviewView()
                            .frame(height: 90)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(accent.opacity(0.3), lineWidth: 1)
                            )

                        Text("LIVE")
                            .font(.system(size: 8, weight: .black))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(accent.opacity(0.85))
                            .clipShape(Capsule())
                            .padding(6)
                    }
                    .frame(maxWidth: centeredControlMaxWidth)
                    Spacer(minLength: 0)
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
                        Spacer(minLength: 4)
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
                    .background(
                        LiquidCardBackground(cornerRadius: 8, tint: accent, liquidGlass: liquidGlass)
                    )
                    .frame(maxWidth: centeredControlMaxWidth)
                    .frame(maxWidth: .infinity)
                }

                // Choose button — doubles as drop target
                Button { vm.browseForVideo() } label: {
                    ZStack {
                        Label(
                            vm.selectedURL == nil ? "Choose a Video File…" : "Swap Video File…",
                            systemImage: "arrow.up.doc.fill"
                        )
                        .frame(maxWidth: .infinity, minHeight: 32)

                        if isDroppingFile {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(accent, lineWidth: 2)
                                .background(accent.opacity(0.1).clipShape(RoundedRectangle(cornerRadius: 8)))
                        }
                    }
                }
                .buttonStyle(DarkButtonStyle(color: accent, liquidGlass: liquidGlass))
                .frame(maxWidth: centeredControlMaxWidth)
                .frame(maxWidth: .infinity)
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
                .background(
                    LiquidCardBackground(cornerRadius: 8, tint: .orange, liquidGlass: liquidGlass)
                )
            }

            // Action grid (fixed column widths so cells don’t stretch oddly in the popover)
            LazyVGrid(columns: actionGridColumns, spacing: 10) {
                if compactIntroMode {
                    gridButton(icon: "sparkles.rectangle.stack.fill", label: "Discover", color: .purple) {
                        DiscoverWindowController.shared.show()
                    }
                    gridButton(icon: "books.vertical.fill", label: "My Library", color: .blue) {
                        showingCollection = true
                    }
                } else {
                    gridButton(
                        icon: vm.isCurrentInCollection() ? "checkmark.circle.fill" : "star.circle.fill",
                        label: vm.isCurrentInCollection() ? "In Library" : "Add to Library",
                        color: vm.isCurrentInCollection() ? .gray : accent,
                        disabled: vm.selectedURL == nil || vm.isCurrentInCollection()
                    ) { vm.addCurrentToCollection() }

                    gridButton(
                        icon: vm.isActive ? "arrow.clockwise.circle.fill" : "play.rectangle.fill",
                        label: vm.isActive ? "Restart Wallpaper" : "Set as Wallpaper",
                        color: .green,
                        disabled: vm.selectedURL == nil
                    ) { vm.applyWallpaper() }

                    gridButton(icon: "stop.circle.fill", label: "Remove Wallpaper",
                               color: .red.opacity(0.85),
                               disabled: !vm.isActive) { vm.removeWallpaper() }

                    gridButton(icon: "sparkles.rectangle.stack.fill", label: "Discover", color: .purple) {
                        DiscoverWindowController.shared.show()
                    }

                    gridButton(icon: "books.vertical.fill", label: "My Library", color: .blue) {
                        showingCollection = true
                    }

                    gridButton(icon: "shuffle.circle.fill", label: "Shuffle", color: .indigo,
                               disabled: shuffleDisabled) { vm.shuffleAndApplyFromLibrary() }
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

            Spacer(minLength: 0)
                .frame(maxHeight: 14)
            Divider().background(Color.white.opacity(0.1))

            // Bottom bar (explicit side widths so gear/power never collapse)
            HStack(spacing: 8) {
                Button {
                    SettingsWindowController.shared.show()
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 40, height: 34)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .frame(width: 40, height: 34, alignment: .center)
                .layoutPriority(2)
                .simultaneousGesture(TapGesture().onEnded { triggerPopoverPulse(.gray) })

                Spacer(minLength: 8)

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
                    .padding(.vertical, 7)
                    .padding(.horizontal, 12)
                }
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(1)
                .buttonStyle(DarkButtonStyle(color: .blue.opacity(0.5), liquidGlass: liquidGlass))
                .disabled(updater.isChecking)

                Spacer(minLength: 8)

                Button { triggerPopoverPulse(.red); NSApp.terminate(nil) } label: {
                    Image(systemName: "power")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 40, height: 34)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .frame(width: 40, height: 34, alignment: .center)
                .layoutPriority(2)
            }
            .frame(maxWidth: .infinity)
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
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 58)
        }
        .buttonStyle(GridButtonStyle(color: color, liquidGlass: liquidGlass))
        .disabled(disabled)
        .opacity(disabled ? 0.45 : 1)
    }

    private func triggerPopoverPulse(_ color: Color) {
        guard buttonRippleFX else { return }
        pulseColor = color
        pulseScale = 0.08
        pulseOpacity = 0.92
        withAnimation(.easeOut(duration: 0.85)) {
            pulseScale = 2.35
            pulseOpacity = 0
        }
    }
}

