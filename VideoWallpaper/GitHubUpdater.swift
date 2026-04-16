//
//  GitHubUpdater.swift
//  VideoWallpaper
//
//  Created by Grant Wilson on 4/15/26.
//


import Foundation
import AppKit
import Combine
import UserNotifications

@MainActor
final class GitHubUpdater: NSObject, ObservableObject {
    
    @Published var isChecking: Bool = false

    private let repo = "gantant/VideoWallpaper"
    
    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self  // Add this
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            print("Notification permission:", granted, error ?? "none")
        }
    }
    

    func checkForUpdates(showNoUpdateAlert: Bool = false) async {
        isChecking = true
        defer { isChecking = false }
        guard let url = URL(string: "https://api.github.com/repos/\(repo)/releases/latest") else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let rawLatest = json["tag_name"] as? String,
                  let htmlURL = json["html_url"] as? String else { return }

            let latestVersion = normalizeVersion(rawLatest)

            let currentVersion = normalizeVersion(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0")

            if isNewer(latest: latestVersion, current: currentVersion) {
                if let assets = json["assets"] as? [[String: Any]],
                   let asset = assets.first(where: { ($0["name"] as? String)?.hasSuffix(".zip") == true }),
                   let downloadString = asset["browser_download_url"] as? String,
                   let downloadURL = URL(string: downloadString) {
                    
                    Task {
                        await self.downloadAndInstall(from: downloadURL)
                    }
                } else {
                    // fallback: open release page if no zip asset found
                    if let fallbackURL = URL(string: htmlURL) {
                        NSWorkspace.shared.open(fallbackURL)
                    }
                }
            } else {
                if showNoUpdateAlert {
                    showAllCaughtUpAlert()
                }
            }

        } catch {
            print("Update check failed:", error)
        }
    }

    private func normalizeVersion(_ version: String) -> String {
        return version
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "v", with: "")
    }

    private func isNewer(latest: String, current: String) -> Bool {
        return latest.compare(current, options: .numeric) == .orderedDescending
    }

    private func downloadAndInstall(from url: URL) async {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)

            let tempZipURL = FileManager.default.temporaryDirectory.appendingPathComponent("update.zip")
            try data.write(to: tempZipURL)

            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("update_unzipped")
            try? FileManager.default.removeItem(at: tempDir)
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            process.arguments = ["-xk", tempZipURL.path, tempDir.path]
            try process.run()
            process.waitUntilExit()

            guard let appBundle = FileManager.default.enumerator(at: tempDir, includingPropertiesForKeys: nil)?
                .compactMap({ $0 as? URL })
                .first(where: { $0.pathExtension == "app" }) else { return }

            let applicationsURL = URL(fileURLWithPath: "/Applications")
            let destinationURL = applicationsURL.appendingPathComponent(appBundle.lastPathComponent)

            try? FileManager.default.removeItem(at: destinationURL)
            try FileManager.default.copyItem(at: appBundle, to: destinationURL)

            NSWorkspace.shared.openApplication(at: destinationURL, configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)

        } catch {
            print("Install failed:", error)
        }
    }
    
    private func showAllCaughtUpAlert() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            print("🔔 Auth status:", settings.authorizationStatus.rawValue)
            // 0=notDetermined, 1=denied, 2=authorized, 3=provisional
        }
        
        let content = UNMutableNotificationContent()
        content.title = "All Caught Up"
        content.body = "You are running the latest version."
        content.sound = UNNotificationSound.default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Notification error:", error)
            } else {
                print("✅ Notification scheduled successfully")
            }
        }
    }
}

extension GitHubUpdater: UNUserNotificationCenterDelegate {
    nonisolated(unsafe) func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])  // Force show even when app is frontmost
    }
}
