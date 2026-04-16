// ============================================================
// VideoWallpaper – ContentView.swift
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
        NSApp.setActivationPolicy(.accessory)

        let p = NSPopover()
        p.contentSize = NSSize(width: 360, height: 560)
        p.behavior = .transient
        p.contentViewController = NSHostingController(
            rootView: ContentView().preferredColorScheme(.dark)
        )
        self.popover = p

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "play.rectangle.fill",
                                     accessibilityDescription: "Video Wallpaper")
        item.button?.action = #selector(togglePopover(_:))
        item.button?.target = self
        self.statusItem = item
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

// MARK: - Cursor Effect Window

class CursorEffectWindow: NSWindow {
    static let shared = CursorEffectWindow()
    private var effectView: CursorEffectView?

    init() {
        super.init(contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: false)
        self.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)))
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.ignoresMouseEvents = true
    }

    func start(ripple: Bool, particles: Bool) {
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return }

        let unionFrame = screens.reduce(CGRect.null) { $0.union($1.frame) }
        self.setFrame(unionFrame, display: true)

        let view = CursorEffectView(ripple: ripple, particles: particles)
        self.contentView = view
        self.effectView = view

        self.orderFrontRegardless()
        view.startTracking()
    }

    func stop() {
        effectView?.stopTracking()
        self.orderOut(nil)
        effectView = nil
    }
}

class CursorEffectView: NSView {
    private var rippleEnabled: Bool
    private var particlesEnabled: Bool
    private var trackingTimer: Timer?
    private var ripples: [(pos: CGPoint, age: CGFloat)] = []
    private var particles: [(pos: CGPoint, vel: CGPoint, age: CGFloat)] = []
    private var lastMousePos: CGPoint = .zero
    private var renderTimer: Timer?

    init(ripple: Bool, particles: Bool) {
        self.rippleEnabled = ripple
        self.particlesEnabled = particles
        super.init(frame: .zero)
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) { fatalError() }

    func startTracking() {
        renderTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func stopTracking() {
        renderTimer?.invalidate()
        renderTimer = nil
    }

    private func tick() {
        let mouse = convertFromScreen(NSEvent.mouseLocation)
        let moved = hypot(mouse.x - lastMousePos.x, mouse.y - lastMousePos.y) > 2

        if moved {
            if rippleEnabled {
                ripples.append((pos: mouse, age: 0))
            }
            if particlesEnabled {
                for _ in 0..<3 {
                    let vel = CGPoint(
                        x: CGFloat.random(in: -2...2),
                        y: CGFloat.random(in: 1...3)
                    )
                    particles.append((pos: mouse, vel: vel, age: 0))
                }
            }
            lastMousePos = mouse
        }

        ripples = ripples.compactMap { r -> (CGPoint, CGFloat)? in
            let newAge = r.age + 0.03
            return newAge < 1.0 ? (r.pos, newAge) : nil
        }
        particles = particles.compactMap { p -> (CGPoint, CGPoint, CGFloat)? in
            let newAge = p.age + 0.04
            let newPos = CGPoint(x: p.pos.x + p.vel.x, y: p.pos.y - p.vel.y)
            return newAge < 1.0 ? (newPos, p.vel, newAge) : nil
        }

        needsDisplay = true
    }

    private func convertFromScreen(_ point: CGPoint) -> CGPoint {
        guard let screen = NSScreen.main else { return point }
        // Flip y: NSScreen origin is bottom-left, NSView origin is also bottom-left
        return CGPoint(x: point.x - screen.frame.minX, y: point.y - screen.frame.minY)
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.clear(dirtyRect)

        // Draw ripples
        for r in ripples {
            let radius = r.age * 60
            let alpha = (1.0 - r.age) * 0.5
            ctx.setStrokeColor(NSColor(white: 1, alpha: alpha).cgColor)
            ctx.setLineWidth(1.5)
            ctx.addEllipse(in: CGRect(x: r.pos.x - radius, y: r.pos.y - radius,
                                      width: radius * 2, height: radius * 2))
            ctx.strokePath()
        }

        // Draw particles
        for p in particles {
            let alpha = (1.0 - p.age) * 0.8
            let size = (1.0 - p.age) * 4
            ctx.setFillColor(NSColor(red: 0.7, green: 0.5, blue: 1.0, alpha: alpha).cgColor)
            ctx.fillEllipse(in: CGRect(x: p.pos.x - size/2, y: p.pos.y - size/2,
                                       width: size, height: size))
        }
    }
}

// MARK: - Wallpaper Window Controller

class WallpaperWindowController: NSObject {
    static let shared = WallpaperWindowController()

    private var wallpaperWindows: [NSWindow] = []
    var players: [AVQueuePlayer] = []
    private var loopers: [AVPlayerLooper] = []
    private var observations: [NSKeyValueObservation] = []

    func setVideo(url: URL, rate: Float = 1.0) async {
        await MainActor.run { removeWallpaper() }

        for screen in NSScreen.screens {
            let player = AVQueuePlayer()
            player.isMuted = true
            player.volume = 0

            let item = AVPlayerItem(url: url)
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

            player.rate = rate

            watchPlayer(player, rate: rate)

            await MainActor.run {
                wallpaperWindows.append(win)
                players.append(player)
                loopers.append(looper)
            }
        }
    }

    func setRate(_ rate: Float) {
        players.forEach { $0.rate = rate }
    }

    private func watchPlayer(_ player: AVQueuePlayer, rate: Float) {
        let obs = player.observe(\.timeControlStatus, options: [.new]) { [weak self] p, _ in
            guard let self else { return }
            if p.timeControlStatus == .paused || p.timeControlStatus == .waitingToPlayAtSpecifiedRate {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    p.rate = rate
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
    @State private var showingSettings = false
    @AppStorage("liquidGlass") private var liquidGlass = false

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
            } else {
                mainView
            }
        }
        .environment(\.controlActiveState, .active)
        .frame(width: 360, height: 560)
    }

    var mainView: some View {
        VStack(spacing: 14) {
            // Header
            VStack(spacing: 4) {
                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(.purple)
                Text("Video Wallpaper")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                Text("Live video on your desktop")
                    .font(.caption)
                    .foregroundStyle(.gray)
            }

            Divider().background(Color.white.opacity(0.1))

            // Current selection
            VStack(spacing: 8) {
                if let url = vm.selectedURL {
                    HStack(spacing: 8) {
                        Image(systemName: "film").foregroundStyle(.purple)
                        Text(url.lastPathComponent)
                            .foregroundStyle(.white).font(.caption)
                            .lineLimit(1).truncationMode(.middle)
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

            // Speed controls
            if vm.isActive {
                VStack(spacing: 6) {
                    HStack {
                        Text("Speed").font(.caption).foregroundStyle(.gray)
                        Spacer()
                        Text(String(format: "%.2fx", vm.playbackRate))
                            .font(.caption.monospacedDigit()).foregroundStyle(.white)
                    }
                    Slider(value: $vm.playbackRate, in: 0.25...2.0, step: 0.05)
                        .tint(.purple)
                        .onChange(of: vm.playbackRate) { _, v in
                            WallpaperWindowController.shared.setRate(Float(v))
                        }
                    HStack(spacing: 6) {
                        ForEach([0.5, 1.0, 1.5, 2.0], id: \.self) { preset in
                            Button {
                                vm.playbackRate = preset
                                WallpaperWindowController.shared.setRate(Float(preset))
                            } label: {
                                Text("\(preset, specifier: "%.1f")x")
                                    .font(.caption2.weight(.semibold))
                                    .padding(.horizontal, 8).padding(.vertical, 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(vm.playbackRate == preset
                                                  ? Color.purple.opacity(0.5)
                                                  : Color.white.opacity(0.08))
                                    )
                                    .foregroundStyle(.white)
                            }.buttonStyle(.plain)
                        }
                    }
                }
                .padding(10)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            // Action grid
            if vm.selectedURL != nil {
                let cols = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
                LazyVGrid(columns: cols, spacing: 10) {
                    gridButton(icon: vm.isCurrentInCollection() ? "checkmark.circle.fill" : "star.fill",
                               label: vm.isCurrentInCollection() ? "Saved" : "Save",
                               color: vm.isCurrentInCollection() ? .gray : .yellow,
                               disabled: vm.isCurrentInCollection()) { vm.addCurrentToCollection() }

                    gridButton(icon: vm.isActive ? "arrow.clockwise" : "desktopcomputer",
                               label: vm.isActive ? "Restart" : "Set",
                               color: .green) { vm.applyWallpaper() }

                    if vm.isActive {
                        gridButton(icon: "stop.circle", label: "Remove", color: .red.opacity(0.85)) {
                            vm.removeWallpaper()
                        }
                    }

                    gridButton(icon: "folder.fill", label: "Collection", color: .blue) {
                        showingCollection = true
                    }
                }
            }

            // Status
            HStack(spacing: 6) {
                Circle().fill(vm.isActive ? Color.green : Color.gray).frame(width: 7, height: 7)
                Text(vm.isActive ? "Wallpaper is active" : "No wallpaper set")
                    .font(.caption).foregroundStyle(.gray)
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
                }.buttonStyle(.plain)

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

    @ViewBuilder
    func gridButton(icon: String, label: String, color: Color, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 20))
                Text(label).font(.caption.weight(.semibold))
            }
            .frame(maxWidth: .infinity, minHeight: 64)
        }
        .buttonStyle(GridButtonStyle(color: color, liquidGlass: liquidGlass))
        .disabled(disabled)
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @ObservedObject var vm: WallpaperViewModel
    @Binding var showingSettings: Bool
    @AppStorage("liquidGlass") private var liquidGlass = false
    @AppStorage("cursorRipple") private var cursorRipple = false
    @AppStorage("cursorParticles") private var cursorParticles = false

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Button { showingSettings = false } label: {
                    Image(systemName: "arrow.left").foregroundStyle(.white)
                }.buttonStyle(.plain)
                Text("Settings").foregroundStyle(.white).font(.headline)
                Spacer()
            }

            ScrollView {
                VStack(spacing: 10) {
                    settingRow(title: "Liquid Glass UI", subtitle: "Requires macOS 26+", tint: .purple) {
                        Toggle("", isOn: $liquidGlass).labelsHidden().toggleStyle(SwitchToggleStyle(tint: .purple))
                    }

                    Divider().background(Color.white.opacity(0.08))
                    Text("Cursor Effects").font(.caption).foregroundStyle(.gray).frame(maxWidth: .infinity, alignment: .leading)

                    settingRow(title: "Ripple Effect", subtitle: "Expanding rings on mouse move", tint: .cyan) {
                        Toggle("", isOn: $cursorRipple).labelsHidden().toggleStyle(SwitchToggleStyle(tint: .cyan))
                    }

                    settingRow(title: "Particle Trail", subtitle: "Purple particles follow cursor", tint: .purple) {
                        Toggle("", isOn: $cursorParticles).labelsHidden().toggleStyle(SwitchToggleStyle(tint: .purple))
                    }
                }
            }
            .onChange(of: cursorRipple) { _, _ in updateCursorEffects() }
            .onChange(of: cursorParticles) { _, _ in updateCursorEffects() }

            Spacer()
        }
        .padding(16)
        .onAppear { updateCursorEffects() }
    }

    private func updateCursorEffects() {
        if cursorRipple || cursorParticles {
            CursorEffectWindow.shared.stop()
            CursorEffectWindow.shared.start(ripple: cursorRipple, particles: cursorParticles)
        } else {
            CursorEffectWindow.shared.stop()
        }
    }

    @ViewBuilder
    func settingRow<C: View>(title: String, subtitle: String, tint: Color, @ViewBuilder control: () -> C) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).foregroundStyle(.white).font(.subheadline.weight(.medium))
                Text(subtitle).foregroundStyle(.gray).font(.caption2)
            }
            Spacer()
            control()
        }
        .padding(12)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Collection View

struct CollectionView: View {
    @ObservedObject var vm: WallpaperViewModel
    @Binding var showingCollection: Bool

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button { showingCollection = false } label: {
                    Image(systemName: "arrow.left").foregroundStyle(.white)
                }.buttonStyle(.plain)
                Text("Collection").foregroundStyle(.white).font(.headline)
                Spacer()
            }

            if vm.savedWallpapers.isEmpty {
                Spacer()
                Text("No saved wallpapers yet.\nSave one from the main screen.")
                    .multilineTextAlignment(.center).font(.caption).foregroundStyle(.gray)
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(vm.savedWallpapers, id: \.self) { url in
                            VStack(spacing: 4) {
                                ThumbnailView(url: url).frame(height: 75)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                Text(url.lastPathComponent)
                                    .font(.caption2).foregroundStyle(.white).lineLimit(1)
                                HStack(spacing: 12) {
                                    Button {
                                        vm.selectFromCollection(url)
                                        showingCollection = false
                                    } label: {
                                        Image(systemName: "play.fill").foregroundStyle(.green)
                                    }.buttonStyle(.plain)
                                    Button { vm.removeFromCollection(url) } label: {
                                        Image(systemName: "trash").foregroundStyle(.red.opacity(0.7))
                                    }.buttonStyle(.plain)
                                }
                            }
                            .padding(8)
                            .background(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }
        }
        .padding(16)
    }
}

// MARK: - Thumbnail View

struct ThumbnailView: View {
    let url: URL
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image).resizable().scaledToFill()
            } else {
                Color.gray.opacity(0.2).onAppear { generateThumbnail() }
            }
        }
    }

    private func generateThumbnail() {
        let asset = AVAsset(url: url)
        let gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true
        DispatchQueue.global().async {
            if let cg = try? gen.copyCGImage(at: .zero, actualTime: nil) {
                let img = NSImage(cgImage: cg, size: .zero)
                DispatchQueue.main.async { self.image = img }
            }
        }
    }
}

// MARK: - View Model

@MainActor
class WallpaperViewModel: ObservableObject {
    @Published var selectedURL: URL?
    @Published var isActive: Bool = false
    @Published var savedWallpapers: [URL] = []
    @Published var playbackRate: Double = 1.0

    init() { loadSaved() }

    func isCurrentInCollection() -> Bool {
        guard let url = selectedURL else { return false }
        return savedWallpapers.contains(url)
    }

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
        let rate = Float(playbackRate)
        Task { await WallpaperWindowController.shared.setVideo(url: url, rate: rate) }
        isActive = true
    }

    func removeWallpaper() {
        WallpaperWindowController.shared.removeWallpaper()
        isActive = false
    }

    func addCurrentToCollection() {
        guard let url = selectedURL, !savedWallpapers.contains(url) else { return }
        savedWallpapers.append(url)
        saveList()
    }

    func removeFromCollection(_ url: URL) {
        savedWallpapers.removeAll { $0 == url }
        saveList()
    }

    func selectFromCollection(_ url: URL) {
        selectedURL = url
        applyWallpaper()
    }

    private func saveList() {
        UserDefaults.standard.set(savedWallpapers.map { $0.path }, forKey: "savedWallpaperPaths")
    }

    private func loadSaved() {
        let paths = UserDefaults.standard.stringArray(forKey: "savedWallpaperPaths") ?? []
        savedWallpapers = paths.compactMap { path -> URL? in
            let url = URL(fileURLWithPath: path)
            return FileManager.default.fileExists(atPath: path) ? url : nil
        }
    }
}

// MARK: - Button Styles

struct GridButtonStyle: ButtonStyle {
    var color: Color
    var liquidGlass: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .contentShape(RoundedRectangle(cornerRadius: 14))
            .background(
                Group {
                    if liquidGlass, #available(macOS 26, *) {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(.ultraThinMaterial)
                            .glassEffect(in: .rect(cornerRadius: 14))
                    } else {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(color.opacity(configuration.isPressed ? 0.35 : 0.22))
                            .overlay(RoundedRectangle(cornerRadius: 14)
                                .stroke(color.opacity(0.5), lineWidth: 1))
                    }
                }
            )
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
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

