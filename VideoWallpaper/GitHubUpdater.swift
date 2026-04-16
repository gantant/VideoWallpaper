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

    @Published var isChecking = false

    // ── Change this to your actual GitHub repo ──
    private let repo = "gantant/VideoWallpaper"

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

        guard let apiURL = URL(string: "https://api.github.com/repos/\(repo)/releases/latest") else {
            print("[Updater] Bad repo URL")
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: apiURL)

            // Surface HTTP errors clearly
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                print("[Updater] GitHub API returned HTTP \(http.statusCode)")
                if showNoUpdateAlert { notify(title: "Update Check Failed",
                                              body: "GitHub returned HTTP \(http.statusCode).") }
                return
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                print("[Updater] Could not parse JSON")
                return
            }

            guard let rawTag  = json["tag_name"] as? String,
                  let htmlURL = json["html_url"]  as? String else {
                print("[Updater] Missing tag_name or html_url in response")
                return
            }

            let latest  = normalize(rawTag)
            let current = normalize(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0")
            print("[Updater] Current: \(current)  Latest: \(latest)")

            guard isNewer(latest: latest, current: current) else {
                print("[Updater] Already up to date")
                if showNoUpdateAlert {
                    notify(title: "You're up to date 🎉",
                           body: "Version \(current) is the latest release.")
                }
                return
            }

            print("[Updater] New version available: \(latest)")

            // Look for a .zip asset to auto-install
            if let assets    = json["assets"]   as? [[String: Any]],
               let zipAsset  = assets.first(where: { ($0["name"] as? String)?.hasSuffix(".zip") == true }),
               let dlString  = zipAsset["browser_download_url"] as? String,
               let dlURL     = URL(string: dlString) {

                notify(title: "Update Available – v\(latest)",
                       body: "Downloading and installing now…")
                await downloadAndInstall(from: dlURL, version: latest)

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

            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.copyItem(at: appBundle, to: destination)

            print("[Updater] Installed to:", destination.path)
            notify(title: "Update Installed – v\(version)",
                   body: "Relaunching VideoWallpaper…")

            // Small delay so the notification can fire before relaunch
            try await Task.sleep(nanoseconds: 1_500_000_000)

            NSWorkspace.shared.openApplication(
                at: destination,
                configuration: NSWorkspace.OpenConfiguration()
            ) { _, _ in }

            // Quit the old instance after handing off
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NSApp.terminate(nil)
            }

        } catch {
            print("[Updater] Install failed:", error)
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
