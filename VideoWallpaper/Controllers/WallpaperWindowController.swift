//
//  WallpaperWindowController.swift
//  VideoWallpaper
//
//  Created by Grant Wilson on 4/19/26.
//


// ============================================================
// WallpaperWindowController.swift
// Manages per-screen wallpaper windows, playback, rotation,
// sleep/wake handling, and hotkey toggle.
// ============================================================

import AppKit
import AVKit
import AVFoundation

class WallpaperWindowController: NSObject {
    static let shared = WallpaperWindowController()

    // MARK: - Per-screen slot
    private struct ScreenSlot {
        var window: NSWindow
        var player: AVQueuePlayer
        var looper: AVPlayerLooper
        var obs: NSKeyValueObservation?
        var displayID: CGDirectDisplayID
    }

    private var slots: [ScreenSlot] = []
    private(set) var currentURL: URL?
    private(set) var currentRate: Float = 1.0
    var isActive: Bool { !slots.isEmpty }

    // Rotation
    private var rotationTimer: Timer?
    private var rotationURLs: [URL] = []
    private var rotationIndex = 0
    var isRotating: Bool { rotationTimer != nil }

    private var sleepObservers: [Any] = []

    override init() {
        super.init()
        setupSleepObservers()
    }

    // MARK: - Set video

    func setVideo(url: URL, rate: Float = 1.0, fade: Bool = true) async {
        currentURL = url
        currentRate = rate
        UserDefaults.standard.set(url.path, forKey: "lastWallpaperPath")
        UserDefaults.standard.set(Double(rate), forKey: "lastPlaybackRate")

        if fade && isActive {
            await MainActor.run {
                slots.forEach { s in
                    NSAnimationContext.runAnimationGroup { ctx in
                        ctx.duration = 0.35
                        s.window.animator().alphaValue = 0
                    }
                }
            }
            try? await Task.sleep(nanoseconds: 380_000_000)
        }

        await MainActor.run { tearDown() }

        for screen in NSScreen.screens {
            await MainActor.run { buildSlot(url: url, screen: screen, rate: rate, fadeIn: fade) }
        }
    }

    @MainActor
    private func buildSlot(url: URL, screen: NSScreen, rate: Float, fadeIn: Bool) {
        let player = AVQueuePlayer()
        player.isMuted = true
        player.volume = 0

        let item = AVPlayerItem(url: url)

        // FPS cap via preferredForwardBufferDuration hint
        let fpsCap = UserDefaults.standard.integer(forKey: "fpsCap")
        if fpsCap == 24 { item.preferredForwardBufferDuration = 1.0 / 24.0 * 4 }
        else if fpsCap == 30 { item.preferredForwardBufferDuration = 1.0 / 30.0 * 4 }

        let looper = AVPlayerLooper(player: player, templateItem: item)

        let pv = AVPlayerView()
        pv.player = player
        pv.videoGravity = .resizeAspectFill
        pv.controlsStyle = .none

        let win = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )
        win.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) - 1)
        win.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        win.isOpaque = true
        win.hasShadow = false
        win.contentView = pv

        if fadeIn {
            win.alphaValue = 0
            win.orderFront(nil)
            player.playImmediately(atRate: rate)
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.35
                win.animator().alphaValue = 1
            }
        } else {
            win.orderFront(nil)
            player.playImmediately(atRate: rate)
        }

        let obs = player.observe(\.timeControlStatus, options: [.new]) { [weak self] p, _ in
            guard let self else { return }
            if p.timeControlStatus == .paused || p.timeControlStatus == .waitingToPlayAtSpecifiedRate {
                let r = self.currentRate
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { p.rate = r }
            }
        }

        let did = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? 0
        slots.append(ScreenSlot(window: win, player: player, looper: looper, obs: obs, displayID: did))
    }

    // MARK: - Screen changes

    func handleScreensChanged() {
        guard let url = currentURL, isActive else { return }

        let liveIDs = Set(NSScreen.screens.compactMap {
            $0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
        })

        // Remove disconnected screens
        slots.removeAll { s in
            if !liveIDs.contains(s.displayID) {
                s.player.pause(); s.window.orderOut(nil); return true
            }
            return false
        }

        // Add new screens
        let existingIDs = Set(slots.map { $0.displayID })
        for screen in NSScreen.screens {
            let did = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? 0
            if !existingIDs.contains(did) {
                buildSlot(url: url, screen: screen, rate: currentRate, fadeIn: true)
            }
        }

        // Resize existing windows (resolution/arrangement may have changed)
        for i in slots.indices {
            guard let screen = NSScreen.screens.first(where: {
                ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID) == slots[i].displayID
            }) else { continue }
            slots[i].window.setFrame(screen.frame, display: true)
        }
    }

    // MARK: - Hotkey toggle

    func toggleActive() {
        if isActive { removeWallpaper() }
        else if let url = currentURL {
            Task { await setVideo(url: url, rate: currentRate) }
        }
    }

    // MARK: - Rate

    func setRate(_ rate: Float) {
        currentRate = rate
        slots.forEach { $0.player.rate = rate }
    }

    // MARK: - Rotation

    func startRotation(urls: [URL], intervalSeconds: Double) {
        stopRotation()
        guard urls.count > 1 else { return }
        rotationURLs = urls
        rotationIndex = 0
        let fade = UserDefaults.standard.object(forKey: "fadeTransition") as? Bool ?? true
        let t = Timer(timeInterval: intervalSeconds, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.rotationIndex = (self.rotationIndex + 1) % self.rotationURLs.count
            let url = self.rotationURLs[self.rotationIndex]
            Task { await self.setVideo(url: url, rate: self.currentRate, fade: fade) }
        }
        t.tolerance = min(intervalSeconds * 0.2, 5)
        RunLoop.main.add(t, forMode: .common)
        rotationTimer = t
    }

    func stopRotation() {
        rotationTimer?.invalidate()
        rotationTimer = nil
    }

    // MARK: - Remove

    func removeWallpaper(stopRot: Bool = true) {
        if stopRot { stopRotation() }
        tearDown()
    }

    private func tearDown() {
        slots.forEach { $0.player.pause(); $0.window.orderOut(nil) }
        slots = []
    }

    // MARK: - Sleep/wake

    private func setupSleepObservers() {
        let nc = NSWorkspace.shared.notificationCenter
        sleepObservers.append(nc.addObserver(
            forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { [weak self] _ in
                self?.slots.forEach { $0.player.pause() }
        })
        sleepObservers.append(nc.addObserver(
            forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { [weak self] _ in
                guard let self else { return }
                let r = self.currentRate
                self.slots.forEach { $0.player.rate = r }
        })
        sleepObservers.append(nc.addObserver(
            forName: NSWorkspace.sessionDidResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
                self?.slots.forEach { $0.player.pause() }
        })
        sleepObservers.append(nc.addObserver(
            forName: NSWorkspace.sessionDidBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
                guard let self else { return }
                let r = self.currentRate
                self.slots.forEach { $0.player.rate = r }
        })
    }
}