import SwiftUI
import AppKit
import QuartzCore
import Combine

// MARK: - State

@MainActor
final class NowPlayingHUDState: ObservableObject {

    @Published var track: NowPlayingTrack = .empty
    @Published var isExpanded: Bool = false
}

// MARK: - Controller

final class NowPlayingHUDController {
    static let shared = NowPlayingHUDController()

    /// How many points of the widget sit **inside** the visible desktop (rest of window is off-screen).
    static let collapsedPeekWidth: CGFloat = 6
    /// Full panel width along the bezel: peek + off-screen tail (drag / hover target).
    static let collapsedPanelDepth: CGFloat = 84
    /// Tall along the bezel so the grabber reads as a slim “blade” (peek stays narrow).
    static let collapsedPanelHeight: CGFloat = 82
    /// Expanded “Dynamic Island” style card (wider pill, room for art + scrubber + controls).
    static let expandedWidth: CGFloat = 310
    static let expandedHeight: CGFloat = 158
    /// Continuous corner radius for a soft “squircle” card (matches min side for a rounded-rect blob).
    static let hudCornerRadius: CGFloat = 44

    let state = NowPlayingHUDState()
    private var panel: NSPanel?
    private var hosting: NSHostingController<NowPlayingHUDView>?
    private var timer: Timer?

    /// User offset from docked position (AppKit coordinates).
    private var dragRestOffset: CGSize = .zero
    private var isDraggingPanel = false
    private var dragGestureBaseline: CGSize = .zero
    private var liveSwiftUITranslation: CGSize = .zero

    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    var dragActive: Bool { isDraggingPanel }

    @objc private func screensChanged() {
        dragRestOffset = .zero
        animateLayout(animated: true)
    }

    func refreshFromDefaults() {
        dragRestOffset = .zero
        let enabled = UserDefaults.standard.bool(forKey: "nowPlayingHUDEnabled")
        if enabled {
            ensurePanel()
            startPolling()
            animateLayout(animated: true)
        } else {
            stopPolling()
            panel?.orderOut(nil)
        }
    }

    func relayout() {
        animateLayout(animated: true)
    }

    /// Call when edge / vertical prefs change so the strip re-anchors.
    func resetDockOffset() {
        dragRestOffset = .zero
        animateLayout(animated: true)
    }

    /// Wallpaper windows use CoreGraphics desktop levels; re-order the HUD after they appear.
    func orderAboveWallpaperIfNeeded() {
        guard UserDefaults.standard.bool(forKey: "nowPlayingHUDEnabled") else { return }
        panel?.orderFrontRegardless()
    }

    /// Seek to a normalized position in the current track (0...1). Updates local state immediately; next poll refines.
    func seekToNormalizedProgress(_ fraction: Double) {
        let f = min(max(fraction, 0), 1)
        var t = state.track
        guard t.durationSeconds > 0, !t.source.isEmpty else { return }
        let pos = f * t.durationSeconds
        NowPlayingAppleScript.setPlayerPosition(app: t.source, seconds: pos)
        t.positionSeconds = pos
        state.track = t
    }

    // MARK: Drag (grabber) — magnetic snap near rest

    func hudDragChanged(translation: CGSize) {
        if !isDraggingPanel {
            isDraggingPanel = true
            dragGestureBaseline = dragRestOffset
        }
        liveSwiftUITranslation = translation
        applyImmediateDragFrame()
    }

    func hudDragEnded(translation: CGSize) {
        isDraggingPanel = false
        liveSwiftUITranslation = .zero

        let appDx = translation.width
        let appDy = -translation.height
        var proposed = CGSize(
            width: dragGestureBaseline.width + appDx,
            height: dragGestureBaseline.height + appDy
        )

        guard let docked = computeDockedFrame() else { return }

        proposed = magneticBlendOffset(proposed, docked: docked)

        let dist = offsetDistanceFromDock(proposed, docked: docked)
        let snapThreshold: CGFloat = 64
        if dist < snapThreshold {
            dragRestOffset = .zero
        } else {
            dragRestOffset = proposed
        }

        animateLayout(animated: true)
    }

    private func magneticBlendOffset(_ proposed: CGSize, docked: NSRect) -> CGSize {
        let d = offsetDistanceFromDock(proposed, docked: docked)
        let zone: CGFloat = 120
        guard d < zone, d > 0 else { return proposed }
        let pull = 1 - (d / zone)
        let factor = 1 - 0.55 * pull
        return CGSize(width: proposed.width * factor, height: proposed.height * factor)
    }

    private func offsetDistanceFromDock(_ offset: CGSize, docked: NSRect) -> CGFloat {
        let f = docked.offsetBy(dx: offset.width, dy: offset.height)
        let c0 = NSPoint(x: docked.midX, y: docked.midY)
        let c1 = NSPoint(x: f.midX, y: f.midY)
        return hypot(c1.x - c0.x, c1.y - c0.y)
    }

    private func applyImmediateDragFrame() {
        guard let panel, let docked = computeDockedFrame() else { return }
        let appDx = liveSwiftUITranslation.width
        let appDy = -liveSwiftUITranslation.height
        var total = CGSize(
            width: dragGestureBaseline.width + appDx,
            height: dragGestureBaseline.height + appDy
        )
        total = magneticBlendOffset(total, docked: docked)
        let target = docked.offsetBy(dx: total.width, dy: total.height)
        panel.setFrame(target, display: true, animate: false)
    }

    private func ensurePanel() {
        guard panel == nil else { return }

        let host = NSHostingController(
            rootView: NowPlayingHUDView(
                state: state,
                collapsedPeekWidth: Self.collapsedPeekWidth,
                collapsedPanelDepth: Self.collapsedPanelDepth,
                collapsedPanelHeight: Self.collapsedPanelHeight,
                expandedWidth: Self.expandedWidth,
                expandedHeight: Self.expandedHeight,
                cornerRadius: Self.hudCornerRadius,
                relayout: { [weak self] in
                    self?.relayout()
                })
        )
        hosting = host
        // Avoid SwiftUI ↔︎ AppKit constraint feedback loops when the panel frame animates (expanded ↔︎ collapsed).
        if #available(macOS 13, *) {
            host.sizingOptions = []
        }
        host.view.translatesAutoresizingMaskIntoConstraints = true
        host.view.autoresizingMask = [.width, .height]

        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: Self.collapsedPanelDepth, height: Self.collapsedPanelHeight),
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        p.isOpaque = false
        p.backgroundColor = .clear
        // SwiftUI draws its own shadows; NSPanel shadows double-composite and cost GPU each frame.
        p.hasShadow = false
        // Above fullscreen edge-to-edge wallpaper (desktop icon window level is far below normal windows).
        p.level = .statusBar
        p.acceptsMouseMovedEvents = true
        p.isMovableByWindowBackground = false
        p.hidesOnDeactivate = false
        p.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        p.title = ""
        p.titleVisibility = .hidden
        p.contentViewController = host
        host.view.wantsLayer = true
        host.view.layer?.drawsAsynchronously = true
        panel = p
    }

    /// Call when the HUD expands or collapses so poll cadence matches UI needs (slower when peek-only).
    func adaptPollingToExpansionState() {
        guard UserDefaults.standard.bool(forKey: "nowPlayingHUDEnabled"), panel != nil else { return }
        startPolling()
    }

    private func startPolling() {
        timer?.invalidate()
        timer = nil
        let t = effectivePollInterval()
        let newTimer = Timer(timeInterval: t, repeats: true) { [weak self] _ in
            self?.poll()
        }
        newTimer.tolerance = min(t * 0.25, 1.2)
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
        poll()
    }

    private func effectivePollInterval() -> TimeInterval {
        let raw = UserDefaults.standard.double(forKey: "nowPlayingPollSeconds")
        let base = raw > 0.25 ? raw : 1.25
        if state.isExpanded {
            return max(0.45, min(base, 2.0))
        }
        return max(1.45, min(base * 1.55, 4.5))
    }

    private func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    private func poll() {
        // NSAppleScript must run on the main thread; the timer uses RunLoop.common + tolerance.
        let artURL = FileManager.default.temporaryDirectory.appendingPathComponent("vw_np_cover.bin")
        guard let snap = NowPlayingAppleScript.fetchTrack(artFile: artURL) else {
            if state.track != .empty {
                state.track = .empty
            }
            return
        }
        // Collapsed: metadata/artwork identity unchanged → skip @Published (avoids full SwiftUI invalidation every tick).
        if !state.isExpanded, snap.samePeekIdentity(as: state.track) {
            return
        }
        state.track = snap
    }

    private func computeDockedFrame() -> NSRect? {
        guard let panel else { return nil }

        if UserDefaults.standard.bool(forKey: "nowPlayingFullScreen") {
            panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        } else {
            panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        }

        guard let screen = NSScreen.main else { return nil }
        let vf = screen.visibleFrame
        let sf = screen.frame
        let expanded = state.isExpanded
        let peek = Self.collapsedPeekWidth
        let depth = Self.collapsedPanelDepth
        let colH = Self.collapsedPanelHeight
        let expW = Self.expandedWidth
        let expH = Self.expandedHeight
        let width: CGFloat = expanded ? expW : depth
        let height: CGFloat = expanded ? expH : colH
        let edge = UserDefaults.standard.string(forKey: "nowPlayingEdge") ?? "trailing"
        let vertical = UserDefaults.standard.string(forKey: "nowPlayingVerticalPosition") ?? "high"

        // Horizontal: use full `frame` so the card hugs the physical screen edge (visibleFrame can leave a gap).
        let x: CGFloat
        if edge == "leading" {
            if expanded {
                x = sf.minX
            } else {
                x = sf.minX + peek - depth
            }
        } else {
            if expanded {
                x = sf.maxX - expW
            } else {
                x = sf.maxX - peek
            }
        }

        let margin: CGFloat = 28
        let y: CGFloat
        switch vertical {
        case "low":
            y = vf.minY + margin
        case "center":
            y = vf.midY - height / 2
        default:
            y = vf.maxY - margin - height
        }

        return NSRect(x: x, y: y, width: width, height: height)
    }

    private func animateLayout(animated: Bool) {
        guard let panel, let docked = computeDockedFrame() else { return }
        let target = docked.offsetBy(dx: dragRestOffset.width, dy: dragRestOffset.height)

        if animated {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.2
                ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.2, 1)
                ctx.allowsImplicitAnimation = true
                panel.animator().setFrame(target, display: true)
            }
        } else {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            panel.setFrame(target, display: true, animate: false)
            CATransaction.commit()
        }
        panel.orderFrontRegardless()
    }
}

// MARK: - SwiftUI

struct NowPlayingHUDView: View {
    @ObservedObject var state: NowPlayingHUDState
    var collapsedPeekWidth: CGFloat
    var collapsedPanelDepth: CGFloat
    var collapsedPanelHeight: CGFloat
    var expandedWidth: CGFloat
    var expandedHeight: CGFloat
    var cornerRadius: CGFloat
    var relayout: () -> Void

    /// Delay collapse so moving between controls doesn’t flicker the panel closed.
    @State private var hoverCollapseWorkItem: DispatchWorkItem?
    /// Collapsed notch: hover = stronger shadow + stroke (no scale — scaling clips inside the narrow panel and reads as “vanishing”).
    @State private var grabberHover = false
    /// Expanded: show transport chrome only while pointer is over the control strip.
    @State private var expandedControlsHover = false

    @AppStorage("nowPlayingHUDStyle") private var hudStyle: String = "artBlur"
    @AppStorage("nowPlayingEdge") private var nowPlayingEdge: String = "trailing"
    @AppStorage("accentHex") private var accentHex: String = "8B5CF6"

    private var accent: Color { Color(hex: accentHex) }

    private var squircle: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    /// “None” = no fill behind controls (see Liqoria-style optional chrome-off); text gets a light legibility shadow over the desktop.
    private var hudUsesTransparentChrome: Bool { hudStyle == "none" }

    private var rootWidth: CGFloat { state.isExpanded ? expandedWidth : collapsedPanelDepth }
    private var rootHeight: CGFloat { state.isExpanded ? expandedHeight : collapsedPanelHeight }

    var body: some View {
        let t = state.track
        Group {
            if state.isExpanded {
                expandedChrome(track: t)
                    .transition(
                        .asymmetric(
                            insertion: .scale(
                                scale: 0.94,
                                anchor: nowPlayingEdge == "trailing" ? .trailing : .leading
                            ).combined(with: .opacity),
                            removal: .scale(
                                scale: 0.96,
                                anchor: nowPlayingEdge == "trailing" ? .trailing : .leading
                            ).combined(with: .opacity)
                        )
                    )
            } else {
                ZStack {
                    Color.black.opacity(0.02)
                    NowPlayingCollapsedNotchTab(
                        isHovered: grabberHover,
                        peekWidth: collapsedPeekWidth,
                        panelDepth: collapsedPanelDepth,
                        panelHeight: collapsedPanelHeight,
                        edgeIsTrailing: nowPlayingEdge == "trailing"
                    )
                }
                .shadow(color: .black.opacity(grabberHover ? 0.45 : 0.22), radius: grabberHover ? 22 : 9, x: 0, y: grabberHover ? 10 : 4)
                .shadow(color: .black.opacity(grabberHover ? 0.22 : 0.12), radius: grabberHover ? 6 : 3, x: 0, y: grabberHover ? 3 : 1)
                .animation(.easeOut(duration: 0.18), value: grabberHover)
                .contentShape(Rectangle())
                .onTapGesture {
                    guard !NowPlayingHUDController.shared.dragActive else { return }
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) {
                        state.isExpanded = true
                    }
                }
                .highPriorityGesture(
                    DragGesture(minimumDistance: 14)
                        .onChanged { v in
                            NowPlayingHUDController.shared.hudDragChanged(translation: v.translation)
                        }
                        .onEnded { v in
                            NowPlayingHUDController.shared.hudDragEnded(translation: v.translation)
                        }
                )
            }
        }
        .onHover { hovering in
            guard !NowPlayingHUDController.shared.dragActive else { return }
            if state.isExpanded {
                grabberHover = false
                if hovering {
                    hoverCollapseWorkItem?.cancel()
                    hoverCollapseWorkItem = nil
                } else {
                    hoverCollapseWorkItem?.cancel()
                    let work = DispatchWorkItem {
                        state.isExpanded = false
                    }
                    hoverCollapseWorkItem = work
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.32, execute: work)
                }
            } else {
                grabberHover = hovering
            }
        }
        .frame(width: rootWidth, height: rootHeight, alignment: .leading)
        .onChange(of: state.isExpanded) { _, expanded in
            if expanded {
                grabberHover = false
            } else {
                expandedControlsHover = false
            }
            NowPlayingHUDController.shared.adaptPollingToExpansionState()
            DispatchQueue.main.async {
                relayout()
            }
        }
        .onAppear {
            DispatchQueue.main.async {
                relayout()
            }
        }
        .onDisappear {
            hoverCollapseWorkItem?.cancel()
            hoverCollapseWorkItem = nil
        }
    }

    @ViewBuilder
    private func expandedChrome(track: NowPlayingTrack) -> some View {
        // One squircle clip so blurred art never reads as a rectangle behind the card.
        ZStack {
            backgroundLayer(artwork: track.artwork)

            if hudStyle == "glass" {
                squircle.fill(Color.white.opacity(0.04))
            } else if !hudUsesTransparentChrome {
                squircle.fill(Color.black.opacity(0.045))
                squircle.fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.11), Color.clear, Color.black.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            }

            VStack(alignment: .leading, spacing: 0) {
                islandHeroRow(track: track)
                    .padding(.bottom, 8)

                if track.durationSeconds > 0 {
                    islandScrubberRow(track: track)
                        .padding(.bottom, 10)
                }

                islandTransportRow(track: track, showOutlines: expandedControlsHover)
                    .onHover { expandedControlsHover = $0 }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .clipShape(squircle)
        .overlay(
            squircle.strokeBorder(
                Color.white.opacity(hudUsesTransparentChrome ? 0.26 : (hudStyle == "glass" ? 0.34 : 0.28)),
                lineWidth: hudUsesTransparentChrome ? 0.4 : 0.45
            )
        )
        .shadow(color: Color.black.opacity(hudUsesTransparentChrome ? 0.2 : 0.34), radius: 14, y: 6)
    }

    @ViewBuilder
    private func islandArtworkView(artwork: NSImage?) -> some View {
        Group {
            if let artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
            } else {
                LinearGradient(
                    colors: [accent.opacity(0.55), Color.black.opacity(0.78)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }

    private func islandHeroRow(track: NowPlayingTrack) -> some View {
        let titleText = track.title.isEmpty ? "Nothing playing" : track.title
        let artistText: String = {
            if track.title.isEmpty { return "Music or Spotify" }
            if !track.artist.isEmpty { return track.artist }
            return "Unknown artist"
        }()
        let legible = hudUsesTransparentChrome

        return HStack(alignment: .center, spacing: 12) {
            islandArtworkView(artwork: track.artwork)
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.38), Color.white.opacity(0.12)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                )
                .shadow(color: .black.opacity(legible ? 0.45 : 0.32), radius: legible ? 14 : 11, y: 4)

            VStack(alignment: .leading, spacing: 5) {
                Text(titleText)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.86)
                    .shadow(color: .black.opacity(legible ? 0.65 : 0), radius: legible ? 3 : 0, y: legible ? 0.5 : 0)

                Text(artistText)
                    .font(.system(size: 12.5, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(1)
                    .shadow(color: .black.opacity(legible ? 0.55 : 0), radius: legible ? 2.5 : 0, y: legible ? 0.5 : 0)

                if track.isPlaying, !track.source.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "waveform")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(accent.opacity(0.95))
                            .shadow(color: .black.opacity(legible ? 0.4 : 0), radius: legible ? 2 : 0, y: 0)
                        Text(track.source)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.48))
                            .shadow(color: .black.opacity(legible ? 0.5 : 0), radius: legible ? 2 : 0, y: 0)
                    }
                    .padding(.top, 1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func islandScrubberRow(track: NowPlayingTrack) -> some View {
        let frac = CGFloat(min(max(track.positionSeconds / track.durationSeconds, 0), 1))
        let remaining = max(0, track.durationSeconds - track.positionSeconds)

        let legible = hudUsesTransparentChrome
        return HStack(spacing: 0) {
            Text(timeString(track.positionSeconds))
                .font(.system(size: 10.5, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.62))
                .monospacedDigit()
                .frame(width: 40, alignment: .leading)
                .shadow(color: .black.opacity(legible ? 0.55 : 0), radius: legible ? 2 : 0, y: 0)

            NowPlayingIslandScrubBar(
                progress: frac,
                accent: accent,
                enabled: !track.source.isEmpty,
                thinTrack: hudStyle == "glass"
            ) { newFrac in
                NowPlayingHUDController.shared.seekToNormalizedProgress(Double(newFrac))
            }

            Text("-" + timeString(remaining))
                .font(.system(size: 10.5, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.62))
                .monospacedDigit()
                .frame(width: 44, alignment: .trailing)
                .shadow(color: .black.opacity(legible ? 0.55 : 0), radius: legible ? 2 : 0, y: 0)
        }
    }

    private func islandTransportRow(track: NowPlayingTrack, showOutlines: Bool) -> some View {
        let legible = hudUsesTransparentChrome
        return HStack(spacing: 0) {
            Spacer(minLength: 8)
            NowPlayingIslandTransportButton(
                system: "backward.fill",
                role: .side,
                accent: accent,
                enabled: !track.source.isEmpty,
                showOutline: showOutlines
            ) {
                NowPlayingAppleScript.sendPlayerCommand(app: track.source, command: "previous track")
            }
            Spacer().frame(width: 18)
            NowPlayingIslandTransportButton(
                system: track.isPlaying ? "pause.fill" : "play.fill",
                role: .primary,
                accent: accent,
                enabled: !track.source.isEmpty,
                showOutline: showOutlines
            ) {
                NowPlayingAppleScript.sendPlayerCommand(app: track.source, command: "playpause")
            }
            Spacer().frame(width: 18)
            NowPlayingIslandTransportButton(
                system: "forward.fill",
                role: .side,
                accent: accent,
                enabled: !track.source.isEmpty,
                showOutline: showOutlines
            ) {
                NowPlayingAppleScript.sendPlayerCommand(app: track.source, command: "next track")
            }
            Spacer(minLength: 8)
        }
        .shadow(color: .black.opacity(legible ? 0.35 : 0), radius: legible ? 6 : 0, y: legible ? 2 : 0)
        .disabled(track.source.isEmpty)
        .opacity(track.source.isEmpty ? 0.38 : 1)
    }

    @ViewBuilder
    private func backgroundLayer(artwork: NSImage?) -> some View {
        switch hudStyle {
        case "none":
            Color.clear
        case "glass":
            if #available(macOS 26, *) {
                Color.clear
                    .glassEffect(in: .rect(cornerRadius: cornerRadius))
            } else {
                Color.black.opacity(0.42)
            }
        default:
            if let artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
                    .blur(radius: 10)
                    .overlay(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.14),
                                Color.black.opacity(0.24)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .clipShape(squircle)
            } else {
                LinearGradient(
                    colors: [
                        Color(red: 0.12, green: 0.12, blue: 0.14),
                        Color(red: 0.06, green: 0.06, blue: 0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }

    private func timeString(_ s: Double) -> String {
        let sec = Int(s.rounded())
        let m = sec / 60
        let r = sec % 60
        return String(format: "%d:%02d", m, r)
    }
}

// MARK: - Island scrubber (tap / drag to seek)

private struct NowPlayingIslandScrubBar: View {
    var progress: CGFloat
    var accent: Color
    var enabled: Bool
    /// Softer, slightly slimmer track for Liquid Glass style.
    var thinTrack: Bool = false
    var onSeek: (CGFloat) -> Void

    @State private var dragProgress: CGFloat?

    private var shown: CGFloat {
        min(max(dragProgress ?? progress, 0), 1)
    }

    private var trackHeight: CGFloat { thinTrack ? 4 : 5.5 }

    var body: some View {
        GeometryReader { geo in
            let w = max(geo.size.width, 1)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(thinTrack ? 0.1 : 0.13))
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [accent.opacity(0.98), accent.opacity(0.52)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(3, w * shown))
            }
            .frame(height: trackHeight)
            .frame(maxHeight: .infinity, alignment: .center)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard enabled else { return }
                        dragProgress = CGFloat(min(max(value.location.x / w, 0), 1))
                    }
                    .onEnded { value in
                        guard enabled else { return }
                        let frac = CGFloat(min(max(value.location.x / w, 0), 1))
                        dragProgress = nil
                        onSeek(frac)
                    }
            )
            .opacity(enabled ? 1 : 0.4)
        }
        .frame(height: 22)
    }
}

// MARK: - Island transport (larger center play / pause)

private enum NowPlayingIslandTransportRole {
    case side
    case primary
}

private struct NowPlayingIslandTransportButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.62), value: configuration.isPressed)
    }
}

private struct NowPlayingIslandTransportButton: View {
    var system: String
    var role: NowPlayingIslandTransportRole
    var accent: Color
    var enabled: Bool
    /// Hairline rings only while the control strip is hovered — calmer default, Tuneful-like clarity on demand.
    var showOutline: Bool = false
    var action: () -> Void

    private var diameter: CGFloat { role == .primary ? 48 : 38 }
    private var iconSize: CGFloat { role == .primary ? 18 : 13 }

    var body: some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: diameter, height: diameter)
                .background {
                    ZStack {
                        if role == .primary {
                            Circle()
                                .fill(.ultraThinMaterial)
                            if showOutline {
                                Circle()
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [Color.white.opacity(0.5), accent.opacity(0.55)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 0.5
                                    )
                            }
                        } else {
                            Circle()
                                .fill(Color.white.opacity(0.14))
                            if showOutline {
                                Circle()
                                    .strokeBorder(Color.white.opacity(0.32), lineWidth: 0.5)
                            }
                        }
                    }
                }
                .shadow(color: .black.opacity(0.22), radius: role == .primary ? 7 : 3, y: 2)
        }
        .buttonStyle(NowPlayingIslandTransportButtonStyle())
        .disabled(!enabled)
    }
}

// MARK: - Collapsed notch (black grabber — same for all HUD materials; hover scales in parent)

private struct NowPlayingCollapsedNotchTab: View {
    var isHovered: Bool
    var peekWidth: CGFloat
    var panelDepth: CGFloat
    var panelHeight: CGFloat
    var edgeIsTrailing: Bool

    var body: some View {
        let capW = max(4, peekWidth)
        let capH = max(24, panelHeight - 4)

        ZStack {
            Color.clear

            HStack(spacing: 0) {
                if edgeIsTrailing {
                    notchCapsuleCore(capW: capW, capH: capH, isHovered: isHovered)
                        .padding(.leading, 1)
                    Spacer(minLength: 0)
                } else {
                    Spacer(minLength: 0)
                    notchCapsuleCore(capW: capW, capH: capH, isHovered: isHovered)
                        .padding(.trailing, 1)
                }
            }
            .frame(width: panelDepth, height: panelHeight)
        }
        .frame(width: panelDepth, height: panelHeight)
        .contentShape(Rectangle())
    }

    private func grabberOutline(capW: CGFloat, capH: CGFloat) -> UnevenRoundedRectangle {
        // Screen-facing edge (long radius) + bezel edge (tighter radius) so every corner reads clearly rounded.
        let towardScreen = min(max(1.5, capW * 0.46), capH * 0.12, 5.5)
        let towardBezel = max(1.1, min(capW * 0.34, 2.25))
        if edgeIsTrailing {
            return UnevenRoundedRectangle(
                topLeadingRadius: towardScreen,
                bottomLeadingRadius: towardScreen,
                bottomTrailingRadius: towardBezel,
                topTrailingRadius: towardBezel,
                style: .continuous
            )
        }
        return UnevenRoundedRectangle(
            topLeadingRadius: towardBezel,
            bottomLeadingRadius: towardBezel,
            bottomTrailingRadius: towardScreen,
            topTrailingRadius: towardScreen,
            style: .continuous
        )
    }

    private func notchCapsuleCore(capW: CGFloat, capH: CGFloat, isHovered: Bool) -> some View {
        let outline = grabberOutline(capW: capW, capH: capH)
        let edgeGradStart = edgeIsTrailing ? UnitPoint.leading : UnitPoint.trailing
        let edgeGradEnd = edgeIsTrailing ? UnitPoint.trailing : UnitPoint.leading

        return ZStack {
            outline
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.06, green: 0.06, blue: 0.07),
                            Color(red: 0.02, green: 0.02, blue: 0.03)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: capW, height: capH)

            outline
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(isHovered ? 0.42 : 0.28),
                            Color.white.opacity(isHovered ? 0.18 : 0.1),
                            Color.black.opacity(0.35)
                        ],
                        startPoint: edgeGradStart,
                        endPoint: edgeGradEnd
                    ),
                    lineWidth: isHovered ? 0.55 : 0.45
                )
                .frame(width: capW, height: capH)
        }
        .frame(width: capW, height: capH)
        .compositingGroup()
        .accessibilityLabel("Now playing — click to open, drag to move")
    }
}

private extension NSRect {
    var midX: CGFloat { origin.x + width / 2 }
    var midY: CGFloat { origin.y + height / 2 }

    func offsetBy(dx: CGFloat, dy: CGFloat) -> NSRect {
        NSRect(x: origin.x + dx, y: origin.y + dy, width: width, height: height)
    }
}

