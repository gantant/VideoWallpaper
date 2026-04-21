// ============================================================
// GitHubUpdater.swift – VideoWallpaper
// ============================================================
// Checks GitHub releases for a newer version, downloads the
// .zip asset, extracts the .app, and replaces the running copy.
// Falls back to opening the release page if no .zip is found.
// ============================================================

import Foundation
import AppKit
import UserNotifications
import Combine

@MainActor
final class GitHubUpdater: NSObject, ObservableObject {
    nonisolated let objectWillChange = ObservableObjectPublisher()

    @Published var isChecking = false

    // ── Change this to your actual GitHub repo ──
    private let repo = "gantant/VideoWallpaper"
    private enum DiagnosticsKey {
        static let lastCheck = "updater.lastCheckISO8601"
        static let status = "updater.status"
        static let latest = "updater.latestVersion"
        static let detail = "updater.detail"
    }

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, err in
            if let err { print("[Updater] Notification auth error:", err) }
            else { print("[Updater] Notification permission granted:", granted) }
        }
    }

    // MARK: - Public

    /// Call with showNoUpdateAlert: true for user-triggered checks so they get feedback.
    func checkForUpdates(showNoUpdateAlert: Bool = false) async {
        guard !isChecking else { return }
        isChecking = true
        defer { isChecking = false }
        persistDiagnostic(status: "Checking…", latest: nil, detail: "Contacting GitHub")

        guard let releasesURL = URL(string: "https://api.github.com/repos/\(repo)/releases"),
              let tagsURL = URL(string: "https://api.github.com/repos/\(repo)/tags") else {
            print("[Updater] Bad repo URL")
            return
        }

        do {
            var resolved = try await fetchBestRelease(from: releasesURL)
            if resolved == nil {
                resolved = try await fetchTagFallback(from: tagsURL)
            }
            guard let release = resolved else {
                persistDiagnostic(status: "Failed", latest: nil, detail: "No releases or tags found")
                if showNoUpdateAlert {
                    notify(title: "Update Check Failed", body: "No releases or tags found in the repository.")
                }
                return
            }

            let rawTag = release.tag
            let htmlURL = release.htmlURL
            let latest  = normalize(rawTag)
            let current = normalize(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0")
            print("[Updater] Current: \(current)  Latest: \(latest)")

            guard isNewer(latest: latest, current: current) else {
                print("[Updater] Already up to date")
                persistDiagnostic(status: "Up to date", latest: latest, detail: "Current \(current)")
                if showNoUpdateAlert {
                    notify(title: "You're up to date 🎉",
                           body: "Version \(current) is the latest release.")
                }
                return
            }

            print("[Updater] New version available: \(latest)")
            persistDiagnostic(status: "Update available", latest: latest, detail: "Current \(current)")

            // Look for a .zip asset to auto-install
            if let downloadURL = release.zipAssetURL {

                notify(title: "Update Available – v\(latest)",
                       body: "Downloading and installing now…")
                await downloadAndInstall(from: downloadURL, version: latest)

            } else {
                // Fallback: open release page
                print("[Updater] No .zip asset found, opening release page")
                notify(title: "Update Available – v\(latest)",
                       body: "Opening the release page so you can download manually.")
                if let url = URL(string: htmlURL) {
                    NSWorkspace.shared.open(url)
                }
            }

        } catch {
            print("[Updater] Network/parse error:", error)
            persistDiagnostic(status: "Failed", latest: nil, detail: error.localizedDescription)
            if showNoUpdateAlert {
                notify(title: "Update Check Failed", body: error.localizedDescription)
            }
        }
    }

    // MARK: - Private helpers

    private func normalize(_ v: String) -> String {
        v.trimmingCharacters(in: .whitespacesAndNewlines)
         .replacingOccurrences(of: "v", with: "")
         .replacingOccurrences(of: "V", with: "")
    }

    private struct ReleaseInfo {
        let tag: String
        let htmlURL: String
        let zipAssetURL: URL?
    }

    private func githubJSON(from url: URL) async throws -> Any {
        var req = URLRequest(url: url)
        req.timeoutInterval = 20
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("VideoWallpaper-Updater", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw NSError(domain: "GitHubUpdater", code: http.statusCode, userInfo: [
                NSLocalizedDescriptionKey: "GitHub returned HTTP \(http.statusCode)."
            ])
        }
        return try JSONSerialization.jsonObject(with: data)
    }

    private func fetchBestRelease(from url: URL) async throws -> ReleaseInfo? {
        guard let releases = try await githubJSON(from: url) as? [[String: Any]] else { return nil }
        guard let best = releases.first(where: { ($0["draft"] as? Bool) != true && ($0["prerelease"] as? Bool) != true }) else {
            return nil
        }
        guard let tag = best["tag_name"] as? String,
              let html = best["html_url"] as? String else { return nil }
        let zip: URL? = ((best["assets"] as? [[String: Any]])?
            .first(where: { ($0["name"] as? String)?.hasSuffix(".zip") == true })?["browser_download_url"] as? String)
            .flatMap(URL.init(string:))
        return ReleaseInfo(tag: tag, htmlURL: html, zipAssetURL: zip)
    }

    private func fetchTagFallback(from url: URL) async throws -> ReleaseInfo? {
        guard
            let tags = try await githubJSON(from: url) as? [[String: Any]],
            let first = tags.first,
            let name = first["name"] as? String
        else { return nil }

        let html = "https://github.com/\(repo)/releases"
        return ReleaseInfo(tag: name, htmlURL: html, zipAssetURL: nil)
    }

    private func persistDiagnostic(status: String, latest: String?, detail: String) {
        let defaults = UserDefaults.standard
        defaults.set(ISO8601DateFormatter().string(from: Date()), forKey: DiagnosticsKey.lastCheck)
        defaults.set(status, forKey: DiagnosticsKey.status)
        defaults.set(latest, forKey: DiagnosticsKey.latest)
        defaults.set(detail, forKey: DiagnosticsKey.detail)
    }

    private func isNewer(latest: String, current: String) -> Bool {
        latest.compare(current, options: .numeric) == .orderedDescending
    }

    private func notify(title: String, body: String) {
        let content      = UNMutableNotificationContent()
        content.title    = title
        content.body     = body
        content.sound    = .default
        let req = UNNotificationRequest(identifier: UUID().uuidString,
                                        content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req) { err in
            if let err { print("[Updater] Notification error:", err) }
        }
    }

    private func downloadAndInstall(from downloadURL: URL, version: String) async {
        do {
            print("[Updater] Downloading from:", downloadURL)
            let (data, _) = try await URLSession.shared.data(from: downloadURL)

            let tmp    = FileManager.default.temporaryDirectory
            let zipURL = tmp.appendingPathComponent("vw_update_\(version).zip")
            let outDir = tmp.appendingPathComponent("vw_update_\(version)")

            try data.write(to: zipURL)
            try? FileManager.default.removeItem(at: outDir)
            try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

            // Unzip using ditto (available on all macOS versions)
            let unzip = Process()
            unzip.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            unzip.arguments     = ["-xk", zipURL.path, outDir.path]
            try unzip.run()
            unzip.waitUntilExit()

            guard unzip.terminationStatus == 0 else {
                print("[Updater] ditto failed with status", unzip.terminationStatus)
                return
            }

            // Find the .app bundle in the extracted directory
            guard let appBundle = FileManager.default
                    .enumerator(at: outDir, includingPropertiesForKeys: nil)?
                    .compactMap({ $0 as? URL })
                    .first(where: { $0.pathExtension == "app" }) else {
                print("[Updater] No .app found in zip")
                return
            }

            print("[Updater] Found app bundle:", appBundle.lastPathComponent)

            let destination = URL(fileURLWithPath: "/Applications")
                .appendingPathComponent(appBundle.lastPathComponent)
            let userDestination = FileManager.default.urls(for: .applicationDirectory, in: .userDomainMask)
                .first?
                .appendingPathComponent(appBundle.lastPathComponent)
                ?? destination

            let appName = appBundle.lastPathComponent
            let sourcePath = appBundle.path
            let destinationPath = destination.path
            let userDestinationPath = userDestination.path

            print("[Updater] Scheduling external install task")

            let script = """
            while pgrep -x "\(appName.replacingOccurrences(of: ".app", with: ""))" > /dev/null; do
                sleep 0.5
            done

            if rm -rf "\(destinationPath)" && cp -R "\(sourcePath)" "\(destinationPath)"; then
                open "\(destinationPath)"
                exit 0
            fi

            mkdir -p "$HOME/Applications"
            rm -rf "\(userDestinationPath)"
            cp -R "\(sourcePath)" "\(userDestinationPath)"
            open "\(userDestinationPath)"
            """

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = ["-c", script]

            do {
                try process.run()
                persistDiagnostic(status: "Install launched", latest: version, detail: "Installer process started")
            } catch {
                print("[Updater] Failed to launch installer process:", error)
                persistDiagnostic(status: "Install failed", latest: version, detail: error.localizedDescription)
                notify(title: "Update Failed", body: error.localizedDescription)
                return
            }

            print("[Updater] Installer process launched")
            return

        } catch {
            print("[Updater] Install failed:", error)
            persistDiagnostic(status: "Install failed", latest: version, detail: error.localizedDescription)
            notify(title: "Update Failed", body: error.localizedDescription)
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension GitHubUpdater: UNUserNotificationCenterDelegate {
    // Show notification banner even when the app is frontmost
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler handler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        handler([.banner, .sound])
    }
}
