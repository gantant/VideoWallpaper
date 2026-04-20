// ============================================================
// WallpaperViewModel.swift
// Main @MainActor observable state for the UI.
// ============================================================

import SwiftUI
import AVFoundation

@MainActor
class WallpaperViewModel: ObservableObject {
    @Published var selectedURL: URL?
    @Published var isActive = false
    @Published var savedWallpapers: [URL] = []
    @Published var playbackRate: Double = 1.0
    @Published var isRotating = false

    init() { loadSaved() }

    // MARK: - Queries

    func isCurrentInCollection() -> Bool {
        guard let url = selectedURL else { return false }
        return savedWallpapers.contains(url)
    }

    // MARK: - Browsing

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

    // MARK: - Playback

    func applyWallpaper() {
        guard let url = selectedURL else { return }
        let rate = Float(playbackRate)
        let fade = UserDefaults.standard.object(forKey: "fadeTransition") as? Bool ?? true
        Task { await WallpaperWindowController.shared.setVideo(url: url, rate: rate, fade: fade) }
        isActive = true
    }

    func removeWallpaper() {
        WallpaperWindowController.shared.removeWallpaper()
        isActive = false
        isRotating = false
    }

    // MARK: - Collection

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

    // MARK: - Rotation

    func startRotation(urls: [URL], intervalSeconds: Double) {
        WallpaperWindowController.shared.startRotation(urls: urls, intervalSeconds: intervalSeconds)
        isRotating = true
        if let first = urls.first { selectedURL = first }
        applyWallpaper()
    }

    func stopRotation() {
        WallpaperWindowController.shared.stopRotation()
        isRotating = false
    }

    // MARK: - Persistence

    private func saveList() {
        UserDefaults.standard.set(savedWallpapers.map { $0.path }, forKey: "savedWallpaperPaths")
    }

    private func loadSaved() {
        let paths = UserDefaults.standard.stringArray(forKey: "savedWallpaperPaths") ?? []
        savedWallpapers = paths.compactMap {
            FileManager.default.fileExists(atPath: $0) ? URL(fileURLWithPath: $0) : nil
        }
    }
}