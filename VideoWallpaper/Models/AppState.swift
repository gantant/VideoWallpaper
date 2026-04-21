// ============================================================
// AppState.swift
// Shared application state
// ============================================================

import Foundation

final class AppState {
    static let shared = AppState()
    let viewModel = WallpaperViewModel()
    private init() {}
}
