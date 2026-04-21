// ============================================================
// WallpaperViewModel.swift
// ============================================================

import SwiftUI
import AVFoundation
import Combine

@MainActor
class WallpaperViewModel: ObservableObject {
    nonisolated let objectWillChange = ObservableObjectPublisher()

    @Published var selectedURL: URL? { willSet { objectWillChange.send() } }
    @Published var isActive: Bool = false { willSet { objectWillChange.send() } }
    @Published var isRotating: Bool = false { willSet { objectWillChange.send() } }
    @Published var playbackRate: Double = 1.0 { willSet { objectWillChange.send() } }
    @Published var savedWallpapers: [URL] = [] { willSet { objectWillChange.send() } }
    @Published var favoritedURLs: Set<URL> = [] { willSet { objectWillChange.send() } }

    init() {
        loadSaved()
        if !savedWallpapers.isEmpty {
            UserDefaults.standard.set(true, forKey: "hasEverChosenVideo")
        }
    }

    private func markHasChosenVideo() {
        UserDefaults.standard.set(true, forKey: "hasEverChosenVideo")
    }

    // MARK: - Queries

    func isCurrentInCollection() -> Bool {
        guard let url = selectedURL else { return false }
        return savedWallpapers.contains(url)
    }

    func isFavorited(_ url: URL) -> Bool { favoritedURLs.contains(url) }

    var sortedWallpapers: [URL] {
        savedWallpapers.sorted { a, b in
            let aFav = favoritedURLs.contains(a)
            let bFav = favoritedURLs.contains(b)
            if aFav != bFav { return aFav }
            return a.lastPathComponent < b.lastPathComponent
        }
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

    func applyURL(_ url: URL) {
        selectedURL = url
        applyWallpaper()
    }

    // MARK: - Playback

    func applyWallpaper() {
        guard let url = selectedURL else { return }
        markHasChosenVideo()
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
        favoritedURLs.remove(url)
        saveList()
        saveFavorites()
        objectWillChange.send()
    }

    func selectFromCollection(_ url: URL) {
        selectedURL = url
        applyWallpaper()
    }

    func toggleFavorite(_ url: URL) {
        if favoritedURLs.contains(url) { favoritedURLs.remove(url) }
        else { favoritedURLs.insert(url) }
        saveFavorites()
        objectWillChange.send()
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

    func shuffleAndApplyFromLibrary() {
        let candidates = savedWallpapers.filter { $0 != selectedURL }
        guard let pick = candidates.randomElement() else { return }
        selectedURL = pick
        applyWallpaper()
    }

    // MARK: - Persistence

    private func saveList() {
        UserDefaults.standard.set(savedWallpapers.map { $0.path }, forKey: "savedWallpaperPaths")
    }

    private func saveFavorites() {
        UserDefaults.standard.set(Array(favoritedURLs.map { $0.path }), forKey: "favoritedPaths")
    }

    private func loadSaved() {
        let paths = UserDefaults.standard.stringArray(forKey: "savedWallpaperPaths") ?? []
        savedWallpapers = paths.compactMap {
            FileManager.default.fileExists(atPath: $0) ? URL(fileURLWithPath: $0) : nil
        }
        let favPaths = UserDefaults.standard.stringArray(forKey: "favoritedPaths") ?? []
        favoritedURLs = Set(favPaths.compactMap {
            FileManager.default.fileExists(atPath: $0) ? URL(fileURLWithPath: $0) : nil
        })
    }
}
