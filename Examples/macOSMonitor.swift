// macOSMonitor.swift
// Demonstrates automated website screenshot monitoring on macOS.
//
// This example captures periodic screenshots of a website and saves them
// to disk, useful for visual regression testing or competitive monitoring.

import Foundation
import SnapAPI

@main
struct WebsiteMonitor {
    static func main() async {
        let apiKey = ProcessInfo.processInfo.environment["SNAPAPI_KEY"] ?? "sk_your_key"
        let client = SnapAPIClient(apiKey: apiKey)

        let urls = [
            "https://example.com",
            "https://news.ycombinator.com",
        ]

        let outputDir = URL(fileURLWithPath: "screenshots")

        // Create output directory if needed
        try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

        print("Website Monitor starting...")
        print("Output directory: \(outputDir.path)")

        // Check quota before starting
        do {
            let quota = try await client.getUsage()
            print("API quota: \(quota.used)/\(quota.total) used, \(quota.remaining) remaining")

            guard quota.remaining >= urls.count else {
                print("Not enough quota remaining. Exiting.")
                return
            }
        } catch {
            print("Warning: could not check quota: \(error)")
        }

        // Capture screenshots for each URL
        for url in urls {
            do {
                let timestamp = ISO8601DateFormatter().string(from: Date())
                let safeName = url
                    .replacingOccurrences(of: "https://", with: "")
                    .replacingOccurrences(of: "/", with: "_")

                var opts = ScreenshotOptions(url: url)
                opts.format    = .png
                opts.fullPage  = true
                opts.width     = 1920
                opts.blockAds  = true
                opts.blockCookieBanners = true

                print("\nCapturing \(url)...")
                let data = try await client.screenshot(opts)

                let filename = "\(safeName)_\(timestamp).png"
                let filePath = outputDir.appendingPathComponent(filename)
                try data.write(to: filePath)
                print("Saved: \(filename) (\(data.count) bytes)")

            } catch let error as SnapAPIError where error.isRetryable {
                print("Retryable error for \(url): \(error.localizedDescription)")
            } catch {
                print("Failed to capture \(url): \(error)")
            }
        }

        print("\nMonitor run complete.")
    }
}
