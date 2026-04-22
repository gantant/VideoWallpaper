//
//  CursorEffectWindow.swift
//  VideoWallpaper
//
//  Created by Grant Wilson on 4/19/26.
//


// ============================================================
// CursorEffectWindow.swift
// Transparent overlay window for ripple + particle effects.
// Optimised: 24 fps, tight caps, union(visibleFrame) backing (not full screen.frame), dirty-rect redraws.
// ============================================================

import AppKit

class CursorEffectWindow: NSWindow {
    static let shared = CursorEffectWindow()
    private var effectView: CursorEffectView?
    private var observers: [Any] = []

    /// Smaller than `union(screen.frame)` — avoids a huge transparent backing store on multi-monitor setups.
    private static func unionVisibleFrames() -> CGRect {
        NSScreen.screens.reduce(CGRect.null) { $0.union($1.visibleFrame) }
    }

    init() {
        super.init(contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: false)
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)))
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        setupObservers()
    }

    func start(ripple: Bool, particles: Bool) {
        guard !NSScreen.screens.isEmpty else { return }
        let frame = Self.unionVisibleFrames()
        setFrame(frame, display: true)
        let v = CursorEffectView(ripple: ripple, particles: particles)
        contentView = v
        effectView = v
        orderFrontRegardless()
        v.startTracking()
    }

    func stop() {
        effectView?.stopTracking()
        orderOut(nil)
        effectView = nil
    }

    private func setupObservers() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.setFrame(Self.unionVisibleFrames(), display: true)
        })
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }
}

class CursorEffectView: NSView {
    private var rippleEnabled: Bool
    private var particlesEnabled: Bool
    private var ripples: [(pos: CGPoint, age: CGFloat)] = []
    private var particles: [(pos: CGPoint, vel: CGPoint, age: CGFloat)] = []
    private var lastMousePos: CGPoint = .zero
    private var renderTimer: Timer?
    /// Padding around ripples/particles for stroke/glow; also used when expanding erase rects.
    private let effectPad: CGFloat = 56
    private func rippleMaxRadius() -> CGFloat {
        120
    }
    /// Previous frame’s effect bounds so the next redraw clears trails as ripples expand/move.
    private var prevEffectDirty: CGRect = .null

    init(ripple: Bool, particles: Bool) {
        self.rippleEnabled = ripple
        self.particlesEnabled = particles
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }
    required init?(coder: NSCoder) { fatalError() }

    func startTracking() {
        // 24 fps + tolerance + common run loop: smooth enough, coalesces with scrolling/event tracking.
        let interval = 1.0 / 24.0
        let t = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.tick()
        }
        t.tolerance = interval * 0.35
        RunLoop.main.add(t, forMode: .common)
        renderTimer = t
    }

    func stopTracking() {
        renderTimer?.invalidate()
        renderTimer = nil
    }

    private func tick() {
        let mouse = convertFromScreen(NSEvent.mouseLocation)
        let moved = hypot(mouse.x - lastMousePos.x, mouse.y - lastMousePos.y) > 3

        if moved {
            if rippleEnabled {
                ripples.append((mouse, 0))
                while ripples.count > 6 { ripples.removeFirst() }
            }
            if particlesEnabled {
                let toAdd = min(1, max(0, 18 - particles.count))
                for _ in 0..<toAdd {
                    particles.append((
                        mouse,
                        CGPoint(x: .random(in: -1.5...1.5), y: .random(in: 0.8...2.5)),
                        0
                    ))
                }
            }
            lastMousePos = mouse
        }

        ripples = ripples.compactMap { r -> (CGPoint, CGFloat)? in
            let a = r.age + 0.006; return a < 1.2 ? (r.pos, a) : nil
        }
        particles = particles.compactMap { p -> (CGPoint, CGPoint, CGFloat)? in
            let a = p.age + 0.03
            let np = CGPoint(x: p.pos.x + p.vel.x, y: p.pos.y - p.vel.y)
            return a < 1 ? (np, p.vel, a) : nil
        }

        var effectBB = CGRect.null
        for r in ripples {
            let rad = r.age * rippleMaxRadius() + 6
            effectBB = effectBB.union(CGRect(x: r.pos.x - rad, y: r.pos.y - rad, width: rad * 2, height: rad * 2))
        }
        for p in particles {
            let sz = (1 - p.age) * 3.5 + 4
            effectBB = effectBB.union(CGRect(x: p.pos.x - sz, y: p.pos.y - sz, width: sz * 2, height: sz * 2))
        }

        let hasEffects = !ripples.isEmpty || !particles.isEmpty
        if hasEffects {
            let d = effectBB.isNull ? bounds : effectBB.insetBy(dx: -effectPad, dy: -effectPad).intersection(bounds)
            let inv = prevEffectDirty.isNull ? d : d.union(prevEffectDirty)
            if !inv.isNull && !inv.isEmpty {
                setNeedsDisplay(inv)
            }
            prevEffectDirty = d
        } else {
            if !prevEffectDirty.isNull && !prevEffectDirty.isEmpty {
                let erase = prevEffectDirty.insetBy(dx: -effectPad, dy: -effectPad).intersection(bounds)
                setNeedsDisplay(erase)
            }
            prevEffectDirty = .null
        }
    }

    private func convertFromScreen(_ pt: CGPoint) -> CGPoint {
        let origin = frame.origin
        return CGPoint(x: pt.x - origin.x, y: pt.y - origin.y)
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.saveGState()
        ctx.clip(to: dirtyRect)
        ctx.clear(dirtyRect)

        for r in ripples {
            let rad = r.age * rippleMaxRadius()
            let alpha = max(0, (1.2 - r.age) / 1.2) * 0.45
            ctx.setStrokeColor(NSColor(white: 1, alpha: alpha).cgColor)
            ctx.setLineWidth(1.2)
            ctx.addEllipse(in: CGRect(
                x: r.pos.x - rad, y: r.pos.y - rad,
                width: rad * 2, height: rad * 2
            ))
            ctx.strokePath()
        }

        for p in particles {
            let a = (1 - p.age) * 0.75
            let sz = (1 - p.age) * 3.5
            ctx.setFillColor(NSColor(red: 0.65, green: 0.45, blue: 1.0, alpha: a).cgColor)
            ctx.fillEllipse(in: CGRect(
                x: p.pos.x - sz / 2, y: p.pos.y - sz / 2,
                width: sz, height: sz
            ))
        }
        ctx.restoreGState()
    }
}