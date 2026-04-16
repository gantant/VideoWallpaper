// ============================================================
// VideoWallpaper – macOS Menu Bar Video Wallpaper App
// ============================================================
// HOW TO SET UP:
//  1. Xcode → File → New → Project → macOS → App
//  2. Name: "VideoWallpaper", Interface: SwiftUI, Language: Swift
//  3. Replace ALL of ContentView.swift with this file
//  4. Delete VideoWallpaperApp.swift (the @main entry is here)
//  5. In Info.plist, add:
//       "Application is agent (UIElement)" → Boolean → YES
//  6. Cmd+R to run!
// ============================================================

import SwiftUI
import AVKit
import AVFoundation
import AppKit
import Combine

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Must be called AFTER launch, not in init
        NSApp.setActivationPolicy(.accessory)

        // Build popover
        let p = NSPopover()
        p.contentSize = NSSize(width: 360, height: 480)
        p.behavior = .transient
        p.contentViewController = NSHostingController(
            rootView: ContentView().preferredColorScheme(.dark)
        )
        self.popover = p

        // Build status item — must retain it strongly
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "play.rectangle.fill",
                                     accessibilityDescription: "Video Wallpaper")
        item.button?.action = #selector(togglePopover(_:))
        item.button?.target = self
        self.statusItem = item  // strong reference — critical!
    }

    @objc func togglePopover(_ sender: AnyObject?) {
        guard let btn = statusItem?.button, let popover else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: btn.bounds, of: btn, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

// MARK: - Wallpaper Window Controller

class WallpaperWindowController: NSObject {
    static let shared = WallpaperWindowController()

    private var wallpaperWindows: [NSWindow] = []
    private var players: [AVQueuePlayer] = []
    private var loopers: [AVPlayerLooper] = []
    private var observations: [NSKeyValueObservation] = []

    func setVideo(url: URL) async {
        await MainActor.run { removeWallpaper() }

        for screen in NSScreen.screens {
            let player = AVQueuePlayer()
            player.isMuted = true
            player.volume = 0

            // Build video-only composition (strips audio track)
            let asset = AVURLAsset(url: url)
            let composition = AVMutableComposition()
            if let videoTrack = try? await asset.loadTracks(withMediaType: .video).first,
               let compTrack = composition.addMutableTrack(withMediaType: .video,
                                                           preferredTrackID: kCMPersistentTrackID_Invalid) {
                let duration = (try? await asset.load(.duration)) ?? .zero
                try? compTrack.insertTimeRange(CMTimeRange(start: .zero, duration: duration),
                                               of: videoTrack, at: .zero)
            }

            let item = AVPlayerItem(asset: composition)
            let looper = AVPlayerLooper(player: player, templateItem: item)

            let playerView = AVPlayerView()
            playerView.player = player
            playerView.videoGravity = .resizeAspectFill
            playerView.controlsStyle = .none

            let win = NSWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false,
                screen: screen
            )
            win.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) - 1)
            win.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            win.isOpaque = true
            win.hasShadow = false
            win.contentView = playerView
            win.orderFront(nil)

            player.play()
            watchPlayer(player)

            await MainActor.run {
                wallpaperWindows.append(win)
                players.append(player)
                loopers.append(looper)
            }
        }
    }

    private func watchPlayer(_ player: AVQueuePlayer) {
        let obs = player.observe(\.timeControlStatus, options: [.new]) { p, _ in
            if p.timeControlStatus == .paused || p.timeControlStatus == .waitingToPlayAtSpecifiedRate {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    p.play()
                }
            }
        }
        observations.append(obs)
    }

    func removeWallpaper() {
        observations.removeAll()
        wallpaperWindows.forEach { $0.orderOut(nil) }
        players.forEach { $0.pause() }
        wallpaperWindows = []
        players = []
        loopers = []
    }

    var isActive: Bool { !wallpaperWindows.isEmpty }
}

// MARK: - Content View

struct ContentView: View {
    @StateObject private var vm = WallpaperViewModel()
    @StateObject private var updater = GitHubUpdater()
    @State private var showingCollection = false

    var body: some View {
        ZStack {
            Color(red: 0.08, green: 0.08, blue: 0.10).ignoresSafeArea()

            if showingCollection {
                CollectionView(vm: vm, showingCollection: $showingCollection)
            } else {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 10) {
                        VStack(spacing: 4) {
                            Image(systemName: "play.rectangle.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(.purple)
                            Text("Video Wallpaper")
                                .font(.title3.bold())
                                .foregroundStyle(.white)
                            Text("Live video on your desktop")
                                .font(.caption)
                                .foregroundStyle(.gray)
                        }

                        Button {
                            showingCollection = true
                        } label: {
                            Image(systemName: "folder.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .frame(width: 36, height: 36)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.25), lineWidth: 1)
                                )
                        }
                        .buttonStyle(HoverGlowButtonStyle())
                    }

                    Divider().background(Color.white.opacity(0.1))

                    // Current selection
                    VStack(spacing: 10) {
                        if let url = vm.selectedURL {
                            HStack(spacing: 8) {
                                Image(systemName: "film").foregroundStyle(.purple)
                                Text(url.lastPathComponent)
                                    .foregroundStyle(.white)
                                    .font(.caption)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer()
                                Button {
                                    vm.selectedURL = nil
                                    vm.removeWallpaper()
                                } label: {
                                    Image(systemName: "xmark.circle.fill").foregroundStyle(.gray)
                                }.buttonStyle(.plain)
                            }
                            .padding(10)
                            .background(Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }

                        Button { vm.browseForVideo() } label: {
                            Label(vm.selectedURL == nil ? "Choose Video…" : "Change Video…",
                                  systemImage: "folder.fill")
                                .frame(maxWidth: .infinity).padding(.vertical, 9)
                        }
                        .buttonStyle(DarkButtonStyle(color: .purple))
                    }

                    // Actions
                    if vm.selectedURL != nil {
                        VStack(spacing: 8) {
                            Button {
                                print("[UI] Save to Collection button pressed")
                                vm.addCurrentToCollection()
                            } label: {
                                Label(vm.isCurrentInCollection() ? "Already in Collection" : "Save to Collection",
                                      systemImage: vm.isCurrentInCollection() ? "checkmark.circle.fill" : "star.fill")
                                    .frame(maxWidth: .infinity).padding(.vertical, 9)
                            }
                            .buttonStyle(DarkButtonStyle(color: vm.isCurrentInCollection() ? .gray : .yellow))
                            .disabled(vm.isCurrentInCollection())

                            Button { vm.applyWallpaper() } label: {
                                Label(vm.isActive ? "Restart" : "Set as Wallpaper",
                                      systemImage: vm.isActive ? "arrow.clockwise" : "desktopcomputer")
                                    .frame(maxWidth: .infinity).padding(.vertical, 9)
                            }.buttonStyle(DarkButtonStyle(color: .green))

                            if vm.isActive {
                                Button { vm.removeWallpaper() } label: {
                                    Label("Remove Wallpaper", systemImage: "stop.circle")
                                        .frame(maxWidth: .infinity).padding(.vertical, 9)
                                }.buttonStyle(DarkButtonStyle(color: .red.opacity(0.8)))
                            }
                        }
                    }

                    // Status
                    HStack(spacing: 6) {
                        Circle()
                            .fill(vm.isActive ? Color.green : Color.gray)
                            .frame(width: 7, height: 7)
                        Text(vm.isActive ? "Wallpaper is active" : "No wallpaper set")
                            .font(.caption).foregroundStyle(.gray)
                    }

                    Divider().background(Color.white.opacity(0.1))

                    Button {
                        Task {
                            await updater.checkForUpdates()
                        }
                    } label: {
                        Label("Check for Updates", systemImage: "arrow.down.circle")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(DarkButtonStyle(color: .blue.opacity(0.5)))
                    Button { NSApp.terminate(nil) } label: {
                        Label("Quit VideoWallpaper", systemImage: "power")
                            .frame(maxWidth: .infinity).padding(.vertical, 8)
                    }.buttonStyle(DarkButtonStyle(color: .white.opacity(0.15)))
                }
            }
        }
        .onAppear {
            Task {
                await updater.checkForUpdates()
            }
        }
        .frame(width: 360, height: 480)
    }
}

// MARK: - View Model

@MainActor
class WallpaperViewModel: ObservableObject {
    func isCurrentInCollection() -> Bool {
        guard let url = selectedURL else { return false }
        return savedWallpapers.contains(url)
    }
    @Published var selectedURL: URL?
    @Published var isActive: Bool = false
    @Published var savedWallpapers: [URL] = []

    init() { loadSaved() }

    func browseForVideo() {
        let panel = NSOpenPanel()
        panel.title = "Select a Video File"
        panel.allowedContentTypes = [.movie, .video, .mpeg4Movie, .quickTimeMovie]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            selectedURL = url
            applyWallpaper()
        }
    }

    func applyWallpaper() {
        guard let url = selectedURL else { return }
        Task { await WallpaperWindowController.shared.setVideo(url: url) }
        isActive = true
    }

    func removeWallpaper() {
        WallpaperWindowController.shared.removeWallpaper()
        isActive = false
    }

    func addCurrentToCollection() {
        print("[Collection] Attempting to add current URL")

        guard let url = selectedURL else {
            print("[Collection] No selectedURL — cannot save")
            return
        }

        print("[Collection] Selected URL: \(url.path)")

        if !savedWallpapers.contains(url) {
            savedWallpapers.append(url)
            print("[Collection] Appended. New count: \(savedWallpapers.count)")
            saveList()
        } else {
            print("[Collection] Already exists: \(url.lastPathComponent)")
        }
    }

    func removeFromCollection(_ url: URL) {
        print("[Collection] Removing: \(url.lastPathComponent)")
        savedWallpapers.removeAll { $0 == url }
        print("[Collection] Count after removal: \(savedWallpapers.count)")
        saveList()
    }

    func selectFromCollection(_ url: URL) {
        print("[Collection] Selected from collection: \(url.lastPathComponent)")
        selectedURL = url
        applyWallpaper()
    }

    private func saveList() {
        let paths = savedWallpapers.map { $0.path }
        print("[Collection] Saving paths: \(paths)")
        UserDefaults.standard.set(paths, forKey: "savedWallpaperPaths")
    }

    private func loadSaved() {
        let paths = UserDefaults.standard.stringArray(forKey: "savedWallpaperPaths") ?? []
        print("[Collection] Loaded raw paths: \(paths)")

        savedWallpapers = paths.compactMap { path -> URL? in
            let exists = FileManager.default.fileExists(atPath: path)
            print("[Collection] Checking path: \(path) exists: \(exists)")
            return exists ? URL(fileURLWithPath: path) : nil
        }

        print("[Collection] Final loaded URLs count: \(savedWallpapers.count)")
    }
}

struct CollectionView: View {
    @ObservedObject var vm: WallpaperViewModel
    @Binding var showingCollection: Bool

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button {
                    showingCollection = false
                } label: {
                    Image(systemName: "arrow.left")
                }
                .buttonStyle(.plain)

                Text("Collection")
                    .foregroundStyle(.white)
                    .font(.headline)

                Spacer()
            }

            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(vm.savedWallpapers, id: \.self) { url in
                        VStack {
                            ThumbnailView(url: url)
                                .frame(height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                            Text(url.lastPathComponent)
                                .font(.caption2)
                                .foregroundStyle(.white)
                                .lineLimit(1)

                            HStack {
                                Button {
                                    vm.selectFromCollection(url)
                                    showingCollection = false
                                } label: {
                                    Image(systemName: "play.fill")
                                }
                                .buttonStyle(.plain)

                                Button {
                                    vm.removeFromCollection(url)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(6)
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
        .padding(16)
    }
}

struct ThumbnailView: View {
    let url: URL
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.gray.opacity(0.2)
                    .onAppear { generateThumbnail() }
            }
        }
    }

    private func generateThumbnail() {
        let asset = AVAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true

        DispatchQueue.global().async {
            if let cgImage = try? generator.copyCGImage(at: .zero, actualTime: nil) {
                let nsImage = NSImage(cgImage: cgImage, size: .zero)
                DispatchQueue.main.async {
                    self.image = nsImage
                }
            }
        }
    }
}

// MARK: - Button Style

struct HoverGlowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        HoverGlow(configuration: configuration)
    }

    struct HoverGlow: View {
        let configuration: Configuration
        @State private var hovering = false

        var body: some View {
            configuration.label
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(configuration.isPressed ? 0.1 : 0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(hovering ? Color.purple : Color.white.opacity(0.25), lineWidth: 1.2)
                        .shadow(color: hovering ? Color.purple.opacity(0.6) : .clear, radius: 8)
                )
                .scaleEffect(configuration.isPressed ? 0.95 : 1)
                .onHover { hovering = $0 }
        }
    }
}

struct DarkButtonStyle: ButtonStyle {
    var color: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(configuration.isPressed ? 0.4 : 0.22))
                    .overlay(RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(color.opacity(0.45), lineWidth: 1))
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}
