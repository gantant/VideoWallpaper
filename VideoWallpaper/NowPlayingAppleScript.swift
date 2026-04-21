import Foundation
import AppKit

enum NowPlayingAppleScript {

    private static func runAppleScript(_ source: String) -> String? {
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else { return nil }
        let out = script.executeAndReturnError(&error)
        if let error {
            print("[NowPlaying] AppleScript error:", error)
            return nil
        }
        return out.stringValue
    }

    private static var includeSpotify: Bool {
        if UserDefaults.standard.object(forKey: "nowPlayingIncludeSpotify") == nil { return true }
        return UserDefaults.standard.bool(forKey: "nowPlayingIncludeSpotify")
    }

    /// Fetches Music or Spotify now playing. Returns tab-delimited metadata + optional artwork file path.
    static func fetchTrack(artFile: URL) -> NowPlayingTrack? {
        let artPath = artFile.path.replacingOccurrences(of: "\"", with: "\\\"")
        let spotifyPlaying = """
        try
            if application "Spotify" is running then
                tell application "Spotify"
                    if player state is playing then
                        set tn to name of current track
                        set ar to artist of current track
                        set al to album of current track
                        set dur to (duration of current track) / 1000
                        set pos to player position
                        try
                            set au to artwork url of current track
                            if au is not missing value and au is not "" then
                                do shell script "/usr/bin/curl -sfL " & quoted form of au & " -o " & quoted form of artPath
                            end if
                        end try
                        return "Spotify\\tplaying\\t" & tn & "\\t" & ar & "\\t" & al & "\\t" & (pos as string) & "\\t" & (dur as string)
                    end if
                end tell
            end if
        end try
        """

        let spotifyPaused = """
        try
            if application "Spotify" is running then
                tell application "Spotify"
                    if player state is paused then
                        set tn to name of current track
                        set ar to artist of current track
                        set al to album of current track
                        set dur to (duration of current track) / 1000
                        set pos to player position
                        try
                            set au to artwork url of current track
                            if au is not missing value and au is not "" then
                                do shell script "/usr/bin/curl -sfL " & quoted form of au & " -o " & quoted form of artPath
                            end if
                        end try
                        return "Spotify\\tpaused\\t" & tn & "\\t" & ar & "\\t" & al & "\\t" & (pos as string) & "\\t" & (dur as string)
                    end if
                end tell
            end if
        end try
        """

        let musicBlock = """
        try
            if application "Music" is running then
                tell application "Music"
                    if (player state is playing) or (player state is paused) then
                        set stLabel to "paused"
                        if player state is playing then set stLabel to "playing"
                        set ct to current track
                        set tn to name of ct
                        set ar to artist of ct
                        set al to album of ct
                        set dur to 0
                        try
                            set dur to duration of ct
                        end try
                        set pos to player position
                        try
                            set rawArt to raw data of artwork 1 of ct
                            set fd to open for access (POSIX file artPath) with write permission
                            set eof fd to 0
                            write rawArt to fd
                            close access fd
                        on error
                            try
                                close access (POSIX file artPath)
                            end try
                        end try
                        return "Music\\t" & stLabel & "\\t" & tn & "\\t" & ar & "\\t" & al & "\\t" & (pos as string) & "\\t" & (dur as string)
                    end if
                end tell
            end if
        end try
        """

        let spotifyPrefix = includeSpotify ? spotifyPlaying : ""
        let spotifySuffix = includeSpotify ? spotifyPaused : ""

        let source = """
        set artPath to "\(artPath)"
        \(spotifyPrefix)
        \(musicBlock)
        \(spotifySuffix)
        return ""
        """

        guard let line = runAppleScript(source), !line.isEmpty else { return nil }
        let parts = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
        guard parts.count >= 7 else { return nil }

        let img: NSImage? = {
            if FileManager.default.fileExists(atPath: artFile.path),
               let data = try? Data(contentsOf: artFile),
               !data.isEmpty {
                return NSImage(data: data)
            }
            return nil
        }()

        let pos = Double(parts[5]) ?? 0
        let dur = Double(parts[6]) ?? 0

        return NowPlayingTrack(
            source: parts[0],
            state: parts[1],
            title: parts[2],
            artist: parts[3],
            album: parts[4],
            positionSeconds: pos,
            durationSeconds: dur,
            artwork: img
        )
    }

    static func sendPlayerCommand(app: String, command: String) {
        guard !app.isEmpty else { return }
        if app == "Spotify" && !includeSpotify { return }
        let escapedApp = app.replacingOccurrences(of: "\"", with: "\\\"")
        let cmd = command.replacingOccurrences(of: "\"", with: "\\\"")
        let source = """
        tell application "\(escapedApp)" to \(cmd)
        """
        _ = runAppleScript(source)
    }

    /// Seeks to `seconds` (Music / Spotify both use seconds for `player position`).
    static func setPlayerPosition(app: String, seconds: Double) {
        guard !app.isEmpty, seconds.isFinite, seconds >= 0 else { return }
        if app == "Spotify" && !includeSpotify { return }
        let escapedApp = app.replacingOccurrences(of: "\"", with: "\\\"")
        let posLiteral = String(format: "%.3f", seconds)
        let source = """
        tell application "\(escapedApp)" to set player position to \(posLiteral)
        """
        _ = runAppleScript(source)
    }
}
