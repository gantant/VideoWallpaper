import SwiftUI
import AppKit

final class SettingsWindowController: NSObject {
    static let shared = SettingsWindowController()

    private var window: NSWindow?
    private var hostingController: NSHostingController<AnyView>?

    func show() {
        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let w = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 520),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        w.title = "Video Wallpaper Settings"
        w.isMovableByWindowBackground = true
        w.titlebarAppearsTransparent = true
        w.titleVisibility = .visible
        w.isOpaque = false
        w.backgroundColor = NSColor(red: 0.08, green: 0.08, blue: 0.1, alpha: 0.95)
        w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        w.level = .floating

        let wrapper = SettingsWindowWrapper()
        let host = NSHostingController(rootView: AnyView(wrapper))
        w.contentViewController = host
        hostingController = host

        w.center()
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        w.orderFront(nil)

        window = w
    }

    func hide() {
        window?.close()
    }

    func toggle() {
        if let existing = window, existing.isVisible {
            existing.orderOut(nil)
        } else {
            show()
        }
    }
}

struct SettingsWindowWrapper: View {
    var body: some View {
        SettingsView(vm: AppState.shared.viewModel, showingSettings: .constant(true))
            .frame(width: 380, height: 500)
    }
}

final class DiscoverWindowController: NSObject {
    static let shared = DiscoverWindowController()

    private var window: NSWindow?
    private var hostingController: NSHostingController<AnyView>?

    func show() {
        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let w = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 450),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        w.title = "Discover Videos"
        w.isMovableByWindowBackground = true
        w.titlebarAppearsTransparent = true
        w.titleVisibility = .visible
        w.isOpaque = false
        w.backgroundColor = NSColor(red: 0.08, green: 0.08, blue: 0.1, alpha: 0.95)
        w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        w.level = .floating

        let wrapper = DiscoverWindowWrapper()
        let host = NSHostingController(rootView: AnyView(wrapper))
        w.contentViewController = host
        hostingController = host

        w.center()
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        w.orderFront(nil)

        window = w
    }

    func hide() {
        window?.close()
    }

    func toggle() {
        if let existing = window, existing.isVisible {
            existing.orderOut(nil)
        } else {
            show()
        }
    }
}

struct DiscoverWindowWrapper: View {
    var body: some View {
        DiscoverView(vm: AppState.shared.viewModel, showingDiscover: .constant(true))
            .frame(width: 580, height: 430)
    }
}