//
//  SettingsView.swift
//  VideoWallpaper
//
//  Created by Grant Wilson on 4/19/26.
//


// ============================================================
// SettingsView.swift
// ============================================================

import SwiftUI

// MARK: - Accent color helper

extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double(int         & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }

    var hex: String {
        let c = NSColor(self).usingColorSpace(.sRGB) ?? .purple
        return String(format: "%02X%02X%02X",
                      Int(c.redComponent * 255),
                      Int(c.greenComponent * 255),
                      Int(c.blueComponent * 255))
    }
}

private let accentPresets: [(name: String, hex: String)] = [
    ("Purple",  "8B5CF6"),
    ("Blue",    "3B82F6"),
    ("Cyan",    "06B6D4"),
    ("Green",   "22C55E"),
    ("Orange",  "F97316"),
    ("Pink",    "EC4899"),
    ("Red",     "EF4444"),
    ("White",   "E5E7EB"),
]

// MARK: - View

struct SettingsView: View {
    @ObservedObject var vm: WallpaperViewModel
    @Binding var showingSettings: Bool
    @StateObject private var updater = GitHubUpdater()

    @AppStorage("liquidGlass")      private var liquidGlass:     Bool   = false
    @AppStorage("fadeTransition")   private var fadeTransition:  Bool   = true
    @AppStorage("autoRestore")      private var autoRestore:     Bool   = false
    @AppStorage("cursorRipple")     private var cursorRipple:    Bool   = false
    @AppStorage("cursorParticles")  private var cursorParticles: Bool   = false
    @AppStorage("buttonRippleFX")   private var buttonRippleFX:  Bool   = false
    @AppStorage("fpsCap")           private var fpsCap:          Int    = 0
    @AppStorage("rotationInterval") private var rotationInterval: Double = 5
    @AppStorage("accentHex")        private var accentHex:       String = "8B5CF6"
    @AppStorage("updater.lastCheckISO8601") private var updaterLastCheck = ""
    @AppStorage("updater.status") private var updaterStatus = "Never run"
    @AppStorage("updater.latestVersion") private var updaterLatest = ""
    @AppStorage("updater.detail") private var updaterDetail = ""

    @State private var rotationSelected: Set<URL> = []

    private var accent: Color { Color(hex: accentHex) }

    var body: some View {
        VStack(spacing: 0) {
            // Nav bar
            HStack {
                BackNavigationButton(title: "Back") { showingSettings = false }
                Text("Settings").foregroundStyle(.white).font(.headline)
                Spacer()
            }
            .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 8)

            ScrollView {
                VStack(spacing: 10) {

                    // MARK: Accent Color
                    sectionHeader("Accent Color")
                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            ForEach(accentPresets, id: \.hex) { preset in
                                Button {
                                    accentHex = preset.hex
                                } label: {
                                    Circle()
                                        .fill(Color(hex: preset.hex))
                                        .frame(width: 26, height: 26)
                                        .overlay(
                                            Circle().stroke(
                                                accentHex == preset.hex ? Color.white : Color.clear,
                                                lineWidth: 2
                                            )
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                            Spacer()
                        }
                        Text("Applied to buttons, sliders, and highlights.")
                            .font(.caption2).foregroundStyle(.gray)
                    }
                    .padding(12)
                    .background(LiquidCardBackground(cornerRadius: 10, tint: accent, liquidGlass: liquidGlass))

                    // MARK: Interface
                    sectionHeader("Interface")
                    settingRow(title: "Liquid Glass UI", subtitle: "Requires macOS 26+") {
                        Toggle("", isOn: $liquidGlass).labelsHidden()
                            .toggleStyle(SwitchToggleStyle(tint: accent))
                    }
                    settingRow(title: "Fade Transition", subtitle: "Crossfade when switching wallpapers") {
                        Toggle("", isOn: $fadeTransition).labelsHidden()
                            .toggleStyle(SwitchToggleStyle(tint: accent))
                    }
                    settingRow(title: "Restore on Launch", subtitle: "Re-apply last wallpaper at startup") {
                        Toggle("", isOn: $autoRestore).labelsHidden()
                            .toggleStyle(SwitchToggleStyle(tint: accent))
                    }
                    settingRow(title: "Button Ripple FX", subtitle: "Glow and radial pulse on button taps") {
                        Toggle("", isOn: $buttonRippleFX).labelsHidden()
                            .toggleStyle(SwitchToggleStyle(tint: accent))
                    }

                    // MARK: Playback Speed
                    sectionHeader("Playback Speed")
                    VStack(spacing: 6) {
                        HStack {
                            Text("Speed").font(.caption).foregroundStyle(.gray)
                            Spacer()
                            Text(String(format: "%.2fx", vm.playbackRate))
                                .font(.caption.monospacedDigit()).foregroundStyle(.white)
                        }
                        Slider(value: $vm.playbackRate, in: 0.25...2.0, step: 0.05)
                            .tint(accent)
                            .onChange(of: vm.playbackRate) { _, v in
                                WallpaperWindowController.shared.setRate(Float(v))
                            }
                        HStack(spacing: 6) {
                            ForEach([0.5, 1.0, 1.5, 2.0], id: \.self) { p in
                                Button {
                                    vm.playbackRate = p
                                    WallpaperWindowController.shared.setRate(Float(p))
                                } label: {
                                    Text(String(format: "%.1fx", p))
                                        .font(.caption2.weight(.semibold))
                                        .padding(.horizontal, 8).padding(.vertical, 4)
                                        .background(RoundedRectangle(cornerRadius: 6)
                                            .fill(vm.playbackRate == p
                                                  ? accent.opacity(0.5)
                                                  : Color.white.opacity(0.08)))
                                        .foregroundStyle(.white)
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(12)
                    .background(LiquidCardBackground(cornerRadius: 10, tint: accent, liquidGlass: liquidGlass))

                    // MARK: FPS Cap
                    sectionHeader("FPS Cap")
                    VStack(spacing: 6) {
                        HStack {
                            Text("Max frame rate").font(.caption).foregroundStyle(.gray)
                            Spacer()
                            Text(fpsCap == 0 ? "Unlimited" : "\(fpsCap) fps")
                                .font(.caption.monospacedDigit()).foregroundStyle(.white)
                        }
                        HStack(spacing: 6) {
                            ForEach([0, 24, 30, 60], id: \.self) { fps in
                                Button { fpsCap = fps } label: {
                                    Text(fps == 0 ? "∞" : "\(fps)")
                                        .font(.caption2.weight(.semibold))
                                        .padding(.horizontal, 10).padding(.vertical, 4)
                                        .background(RoundedRectangle(cornerRadius: 6)
                                            .fill(fpsCap == fps
                                                  ? accent.opacity(0.5)
                                                  : Color.white.opacity(0.08)))
                                        .foregroundStyle(.white)
                                }.buttonStyle(.plain)
                            }
                        }
                        Text("Takes effect next time you set a wallpaper.")
                            .font(.caption2).foregroundStyle(.gray)
                    }
                    .padding(12)
                    .background(LiquidCardBackground(cornerRadius: 10, tint: accent, liquidGlass: liquidGlass))

                    // MARK: Rotation
                    sectionHeader("Auto-Rotation")
                    VStack(spacing: 8) {
                        HStack {
                            Text("Switch every").font(.caption).foregroundStyle(.gray)
                            Spacer()
                            Text(rotationInterval < 1
                                 ? "\(Int(rotationInterval * 60))s"
                                 : "\(Int(rotationInterval))m")
                                .font(.caption.monospacedDigit()).foregroundStyle(.white)
                        }
                        Slider(value: $rotationInterval, in: 0.5...60, step: 0.5).tint(accent)

                        if vm.savedWallpapers.isEmpty {
                            Text("Add videos to your Library to use rotation.")
                                .font(.caption2).foregroundStyle(.gray)
                        } else {
                            Text("Select videos to rotate through:")
                                .font(.caption2).foregroundStyle(.gray)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            VStack(spacing: 4) {
                                ForEach(vm.savedWallpapers, id: \.self) { url in
                                    HStack(spacing: 8) {
                                        Image(systemName: rotationSelected.contains(url)
                                              ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(rotationSelected.contains(url) ? accent : .gray)
                                            .font(.caption)
                                        Text(url.lastPathComponent)
                                            .font(.caption).foregroundStyle(.white).lineLimit(1)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 8).padding(.vertical, 6)
                                    .background(Color.white.opacity(rotationSelected.contains(url) ? 0.1 : 0.03))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                    .onTapGesture {
                                        if rotationSelected.contains(url) { rotationSelected.remove(url) }
                                        else { rotationSelected.insert(url) }
                                    }
                                }
                            }

                            if vm.isRotating {
                                Button { vm.stopRotation() } label: {
                                    Label("Stop Rotation", systemImage: "stop.circle")
                                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                                }.buttonStyle(DarkButtonStyle(color: .red.opacity(0.7), liquidGlass: liquidGlass))
                            } else {
                                Button {
                                    let urls = vm.savedWallpapers.filter { rotationSelected.contains($0) }
                                    guard urls.count >= 2 else { return }
                                    vm.startRotation(urls: urls, intervalSeconds: rotationInterval * 60)
                                } label: {
                                    Label("Start Rotation", systemImage: "play.fill")
                                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                                }
                                .buttonStyle(DarkButtonStyle(color: accent, liquidGlass: liquidGlass))
                                .disabled(rotationSelected.count < 2)
                                if rotationSelected.count < 2 {
                                    Text("Select at least 2 videos.")
                                        .font(.caption2).foregroundStyle(.gray)
                                }
                            }
                        }
                    }
                    .padding(12)
                    .background(LiquidCardBackground(cornerRadius: 10, tint: accent, liquidGlass: liquidGlass))

                    // MARK: Cursor Effects
                    sectionHeader("Cursor Effects")
                    settingRow(title: "Ripple Effect", subtitle: "Expanding rings on mouse move") {
                        Toggle("", isOn: $cursorRipple).labelsHidden()
                            .toggleStyle(SwitchToggleStyle(tint: accent))
                    }
                    settingRow(title: "Particle Trail", subtitle: "Particles follow your cursor") {
                        Toggle("", isOn: $cursorParticles).labelsHidden()
                            .toggleStyle(SwitchToggleStyle(tint: accent))
                    }

                    // MARK: Hotkey
                    sectionHeader("Keyboard Shortcut")
                    HStack(spacing: 8) {
                        Image(systemName: "keyboard").foregroundStyle(.gray)
                        Text("Toggle wallpaper on/off")
                            .font(.caption).foregroundStyle(.white)
                        Spacer()
                        Text("⌘ ⇧ W")
                            .font(.caption.monospacedDigit())
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color.white.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                            .foregroundStyle(.gray)
                    }
                    .padding(12).background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    // MARK: Updater Diagnostics
                    sectionHeader("Updater Diagnostics")
                    VStack(alignment: .leading, spacing: 8) {
                        diagnosticRow("Status", updaterStatus)
                        diagnosticRow("Latest Seen", updaterLatest.isEmpty ? "—" : updaterLatest)
                        diagnosticRow("Last Check", updaterLastCheck.isEmpty ? "Never" : updaterLastCheck)
                        diagnosticRow("Detail", updaterDetail.isEmpty ? "—" : updaterDetail)

                        Button {
                            Task { await updater.checkForUpdates(showNoUpdateAlert: true) }
                        } label: {
                            Label(updater.isChecking ? "Checking…" : "Run Diagnostic Check",
                                  systemImage: updater.isChecking ? "arrow.trianglehead.2.clockwise" : "stethoscope")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(DarkButtonStyle(color: accent, liquidGlass: liquidGlass))
                        .disabled(updater.isChecking)
                    }
                    .padding(12)
                    .background(LiquidCardBackground(cornerRadius: 10, tint: accent, liquidGlass: liquidGlass))

                    // MARK: Sources
                    sectionHeader("Free Wallpaper Sources")
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach([
                            ("Pexels Videos",  "https://www.pexels.com/videos/"),
                            ("Pixabay Videos", "https://pixabay.com/videos/"),
                            ("Coverr",         "https://coverr.co/"),
                            ("Mixkit",         "https://mixkit.co/free-stock-video/"),
                            ("Videvo",         "https://www.videvo.net/"),
                        ], id: \.0) { name, link in
                            Link(name, destination: URL(string: link)!)
                                .font(.caption).foregroundStyle(accent)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(LiquidCardBackground(cornerRadius: 10, tint: accent, liquidGlass: liquidGlass))
                }
                .padding(.horizontal, 16).padding(.bottom, 16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onChange(of: cursorRipple)    { _, _ in updateCursor() }
        .onChange(of: cursorParticles) { _, _ in updateCursor() }
        .onAppear { updateCursor() }
    }

    private func updateCursor() {
        if cursorRipple || cursorParticles {
            CursorEffectWindow.shared.stop()
            CursorEffectWindow.shared.start(ripple: cursorRipple, particles: cursorParticles)
        } else {
            CursorEffectWindow.shared.stop()
        }
    }

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        Text(title).font(.caption).foregroundStyle(.gray)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func settingRow<C: View>(
        title: String, subtitle: String,
        @ViewBuilder control: () -> C
    ) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).foregroundStyle(.white).font(.subheadline.weight(.medium))
                Text(subtitle).foregroundStyle(.gray).font(.caption2)
            }
            Spacer()
            control()
        }
        .padding(12)
        .background(LiquidCardBackground(cornerRadius: 10, tint: accent, liquidGlass: liquidGlass))
    }

    @ViewBuilder
    private func diagnosticRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.caption2).foregroundStyle(.gray)
            Spacer()
            Text(value)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.white)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}
