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
        p.contentSize = NSSize(width: 360, height: 560)
        p.behavior = .transient
        p.contentViewController = NSHostingController(
            rootView: ContentView(vm: AppState.shared.viewModel).preferredColorScheme(.dark)
        )
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

        // Auto-restore via shared view model so UI stays in sync
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

