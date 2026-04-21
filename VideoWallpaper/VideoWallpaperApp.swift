//
//  VideoWallpaperApp.swift
//  VideoWallpaper
//
//  Created by Grant Wilson on 4/14/26.
//

// ============================================================
// VideoWallpaperApp.swift
// Entry point + AppDelegate
// ============================================================

import SwiftUI
import AppKit
import Carbon

/// Keeps `NSPopover.contentSize` in sync with SwiftUI’s vertical fitting size (avoids a dead zone or clipping).
@MainActor
final class VideoWallpaperPopoverHost: NSHostingController<ContentView> {
    weak var popover: NSPopover?

    /// Resizing the popover from `viewDidLayout` causes layout↔size feedback loops and visible stutter; debounce coalesces passes.
    private var popoverSizeDebounce: DispatchWorkItem?

    override func viewDidLayout() {
        super.viewDidLayout()
        schedulePopoverContentSizeSync()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        popoverSizeDebounce?.cancel()
        applyPopoverContentSizeIfNeeded()
    }

    deinit {
        popoverSizeDebounce?.cancel()
    }

    private func schedulePopoverContentSizeSync() {
        popoverSizeDebounce?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.applyPopoverContentSizeIfNeeded()
        }
        popoverSizeDebounce = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: work)
    }

    private func applyPopoverContentSizeIfNeeded() {
        guard let popover, popover.isShown else { return }
        let targetWidth: CGFloat = 360
        view.layoutSubtreeIfNeeded()
        var h = view.fittingSize.height
        if h < 80 { h = view.frame.height }
        h = max(260, min(920, h))
        let sz = NSSize(width: targetWidth, height: h)
        // Large threshold + debounce: avoid churn from sub-pixel SwiftUI layout changes.
        if abs(popover.contentSize.height - h) > 2.75 || abs(popover.contentSize.width - targetWidth) > 1 {
            popover.contentSize = sz
        }
    }
}

@main
struct VideoWallpaperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene { Settings { EmptyView() } }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    private var hotKeyRef: EventHotKeyRef?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let p = NSPopover()
        p.contentSize = NSSize(width: 360, height: 480)
        p.behavior = .transient
        let host = VideoWallpaperPopoverHost(
            rootView: ContentView(vm: AppState.shared.viewModel)
        )
        host.popover = p
        p.contentViewController = host
        self.popover = p

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(
            systemSymbolName: "play.rectangle.fill",
            accessibilityDescription: "Video Wallpaper"
        )
        item.button?.action = #selector(togglePopover(_:))
        item.button?.target = self
        self.statusItem = item

        registerHotKey()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        if UserDefaults.standard.bool(forKey: "autoRestore"),
           let path = UserDefaults.standard.string(forKey: "lastWallpaperPath"),
           FileManager.default.fileExists(atPath: path) {
            let url = URL(fileURLWithPath: path)
            let rate = UserDefaults.standard.double(forKey: "lastPlaybackRate")
            let playbackRate = rate > 0 ? rate : 1.0
            let viewModel = AppState.shared.viewModel
            viewModel.playbackRate = playbackRate
            viewModel.selectedURL = url
            UserDefaults.standard.set(true, forKey: "hasEverChosenVideo")
            Task {
                await WallpaperWindowController.shared.setVideo(url: url, rate: Float(playbackRate), fade: false)
                await MainActor.run { viewModel.isActive = true }
            }
        }

        NowPlayingHUDController.shared.refreshFromDefaults()
    }

    @objc func togglePopover(_ sender: AnyObject?) {
        guard let popover = self.popover,
              let item = self.statusItem,
              let btn = item.button,
              !btn.bounds.isEmpty else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: btn.bounds, of: btn, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    @objc private func screensChanged() {
        WallpaperWindowController.shared.handleScreensChanged()
    }

    private func registerHotKey() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ -> OSStatus in
            var hkID = EventHotKeyID()
            GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil, MemoryLayout<EventHotKeyID>.size, nil, &hkID
            )
            if hkID.id == 1 {
                DispatchQueue.main.async {
                    WallpaperWindowController.shared.toggleActive()
                }
            }
            return noErr
        }, 1, &eventType, nil, nil)

        let hkID = EventHotKeyID(signature: OSType(0x5657_4C50), id: 1)
        RegisterEventHotKey(
            UInt32(kVK_ANSI_W),
            UInt32(cmdKey | shiftKey),
            hkID,
            GetApplicationEventTarget(),
            0, &hotKeyRef
        )
    }
}

