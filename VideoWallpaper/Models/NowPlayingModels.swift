import Foundation
import AppKit

struct NowPlayingTrack: Equatable {
    var source: String
    var state: String
    var title: String
    var artist: String
    var album: String
    var positionSeconds: Double
    var durationSeconds: Double
    var artwork: NSImage?

    var isPlaying: Bool { state.lowercased() == "playing" }

    static let empty = NowPlayingTrack(
        source: "",
        state: "",
        title: "",
        artist: "",
        album: "",
        positionSeconds: 0,
        durationSeconds: 0,
        artwork: nil
    )

    /// Compares everything the **collapsed** HUD shows; ignores `positionSeconds` so we can skip `@Published` churn while music plays.
    func samePeekIdentity(as other: NowPlayingTrack) -> Bool {
        source == other.source
            && state == other.state
            && title == other.title
            && artist == other.artist
            && album == other.album
            && abs(durationSeconds - other.durationSeconds) < 0.02
    }
}
