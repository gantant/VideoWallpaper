//
//  VideoWallpaperApp.swift
//  VideoWallpaper
//
//  Created by Grant Wilson on 4/14/26.
//

import SwiftUI

// MARK: - Entry Point

@main
struct VideoWallpaperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        Settings { EmptyView() }
    }
}
