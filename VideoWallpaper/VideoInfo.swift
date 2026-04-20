//
//  VideoInfo.swift
//  VideoWallpaper
//
//  Created by Grant Wilson on 4/19/26.
//


// ============================================================
// VideoInfo.swift
// Async video metadata loader + info sheet view.
// ============================================================

import SwiftUI
import AVFoundation

struct VideoInfo {
    var resolution: String = "—"
    var duration:   String = "—"
    var fileSize:   String = "—"
    var codec:      String = "—"

    static func load(from url: URL) async -> VideoInfo {
        var info = VideoInfo()

        // File size
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let bytes = attrs[.size] as? Int64 {
            let mb = Double(bytes) / 1_048_576
            info.fileSize = mb >= 1024
                ? String(format: "%.1f GB", mb / 1024)
                : String(format: "%.1f MB", mb)
        }

        let asset = AVURLAsset(url: url)

        // Duration — use CMTime directly
        do {
            let dur = try await asset.load(.duration)
            let s = max(0, Int(CMTimeGetSeconds(dur)))
            info.duration = s >= 3600
                ? String(format: "%d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
                : String(format: "%d:%02d", s / 60, s % 60)
        } catch { info.duration = "—" }

        // Video tracks — resolution + codec
        do {
            let tracks = try await asset.loadTracks(withMediaType: .video)
            if let vt = tracks.first {
                if let size = try? await vt.load(.naturalSize) {
                    let t = (try? await vt.load(.preferredTransform)) ?? .identity
                    let transformed = size.applying(t)
                    let w = Int(abs(transformed.width))
                    let h = Int(abs(transformed.height))
                    info.resolution = "\(max(w,h))×\(min(w,h))"
                }
                if let descs = try? await vt.load(.formatDescriptions),
                   let fmt = descs.first {
                    let fcc = CMFormatDescriptionGetMediaSubType(fmt)
                    let data = withUnsafeBytes(of: fcc.bigEndian) { Data($0) }
                    info.codec = String(data: data, encoding: .ascii)?
                        .trimmingCharacters(in: .whitespaces) ?? "—"
                }
            }
        } catch { info.resolution = "—" }

        return info
    }
}

// MARK: - Info Sheet

struct VideoInfoSheet: View {
    let url: URL
    let info: VideoInfo
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Video Info")
                    .font(.headline).foregroundStyle(.white)
                Spacer()
                Button { isPresented = false } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.gray)
                }.buttonStyle(.plain)
            }

            VStack(spacing: 6) {
                row("File",       url.lastPathComponent)
                row("Resolution", info.resolution)
                row("Duration",   info.duration)
                row("File Size",  info.fileSize)
                row("Codec",      info.codec)
            }

            Button {
                NSWorkspace.shared.activateFileViewerSelecting([url])
                isPresented = false
            } label: {
                Label("Show in Finder", systemImage: "folder")
                    .frame(maxWidth: .infinity).padding(.vertical, 8)
            }.buttonStyle(DarkButtonStyle(color: .blue))
        }
        .padding(20)
        .frame(width: 300)
        .background(Color(red: 0.08, green: 0.08, blue: 0.10))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.caption).foregroundStyle(.gray)
            Spacer()
            Text(value).font(.caption.monospacedDigit()).foregroundStyle(.white)
                .lineLimit(1).truncationMode(.middle)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
