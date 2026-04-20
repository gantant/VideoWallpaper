//
//  CursorEffectWindow.swift
//  VideoWallpaper
//
//  Created by Grant Wilson on 4/19/26.
//


// ============================================================
// CursorEffectWindow.swift
// Transparent overlay window for ripple + particle effects.
// Optimised: 30 fps, particle cap, dirty-rect only redraws.
// ============================================================

import AppKit

class CursorEffectWindow: NSWindow {
    static let shared = CursorEffectWindow()
    private var effectView: CursorEffectView?

    init() {
        super.init(contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: false)
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)))
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
    }

    func start(ripple: Bool, particles: Bool) {
        guard !NSScreen.screens.isEmpty else { return }
        let frame = NSScreen.screens.reduce(CGRect.null) { $0.union($1.frame) }
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
}

class CursorEffectView: NSView {
    private var rippleEnabled: Bool
    private var particlesEnabled: Bool
    private var ripples: [(pos: CGPoint, age: CGFloat)] = []
    private var particles: [(pos: CGPoint, vel: CGPoint, age: CGFloat)] = []
    private var lastMousePos: CGPoint = .zero
    private var renderTimer: Timer?
    private var frameCount = 0

    init(ripple: Bool, particles: Bool) {
        self.rippleEnabled = ripple
        self.particlesEnabled = particles
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }
    required init?(coder: NSCoder) { fatalError() }

    func startTracking() {
        // 30 fps — halves GPU pressure vs 60 fps
        renderTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
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
            }
            if particlesEnabled {
                // Cap at 40 total, add max 2 per tick
                let toAdd = min(2, max(0, 40 - particles.count))
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
            let a = r.age + 0.04; return a < 1 ? (r.pos, a) : nil
        }
        particles = particles.compactMap { p -> (CGPoint, CGPoint, CGFloat)? in
            let a = p.age + 0.05
            let np = CGPoint(x: p.pos.x + p.vel.x, y: p.pos.y - p.vel.y)
            return a < 1 ? (np, p.vel, a) : nil
        }

        if !ripples.isEmpty || !particles.isEmpty {
            setNeedsDisplay(bounds)
        } else if frameCount % 30 == 0 {
            // Periodic clear to avoid stale pixels
            setNeedsDisplay(bounds)
        }
        frameCount += 1
    }

    private func convertFromScreen(_ pt: CGPoint) -> CGPoint {
        guard let s = NSScreen.main else { return pt }
        return CGPoint(x: pt.x - s.frame.minX, y: pt.y - s.frame.minY)
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.clear(bounds)

        for r in ripples {
            let rad = r.age * 50
            ctx.setStrokeColor(NSColor(white: 1, alpha: (1 - r.age) * 0.45).cgColor)
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
    }
}