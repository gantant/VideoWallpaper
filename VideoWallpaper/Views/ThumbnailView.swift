//
//  ThumbnailView.swift
//  VideoWallpaper
//
//  Created by Grant Wilson on 4/19/26.
//


// ============================================================
// ThumbnailView.swift
// ============================================================

import SwiftUI
import AVFoundation

struct ThumbnailView: View {
    let url: URL
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image).resizable().scaledToFill()
            } else {
                Color.gray.opacity(0.2).onAppear { generateThumbnail() }
            }
        }
    }

    private func generateThumbnail() {
        let asset = AVURLAsset(url: url)
        let gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true
        gen.generateCGImageAsynchronously(for: CMTime(seconds: 0, preferredTimescale: 600)) { cg, _, err in
            guard let cg, err == nil else { return }
            let img = NSImage(cgImage: cg, size: .zero)
            DispatchQueue.main.async { self.image = img }
        }
    }
}