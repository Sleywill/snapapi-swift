// iOSExample.swift
// Demonstrates SnapAPI usage in an iOS app context.
//
// Add to your iOS project that includes the SnapAPI package dependency.
// This shows common patterns for capturing screenshots within an iOS app.

import Foundation
import SnapAPI

#if canImport(UIKit)
import UIKit
#endif

// MARK: - Screenshot Service (iOS)

/// A service class that wraps SnapAPI for use in an iOS app.
///
/// Create a single instance and share it across your app:
/// ```swift
/// let screenshotService = ScreenshotService(apiKey: "sk_your_key")
/// ```
final class ScreenshotService {
    private let client: SnapAPIClient

    init(apiKey: String) {
        self.client = SnapAPIClient(apiKey: apiKey)
    }

    /// Capture a website screenshot and return it as a UIImage.
    func captureScreenshot(url: String, fullPage: Bool = false) async throws -> Data {
        var opts = ScreenshotOptions(url: url)
        opts.format   = .png
        opts.fullPage = fullPage
        opts.width    = 390  // iPhone 14 Pro width
        return try await client.screenshot(opts)
    }

    /// Capture a mobile-optimized screenshot with device emulation.
    func captureMobileScreenshot(url: String) async throws -> Data {
        var opts = ScreenshotOptions(url: url)
        opts.format = .png
        opts.device = "iPhone 14 Pro"
        opts.blockAds = true
        opts.blockCookieBanners = true
        return try await client.screenshot(opts)
    }

    /// Generate a PDF report from a URL.
    func generatePDFReport(url: String) async throws -> Data {
        var opts = PdfOptions(url: url)
        opts.pageFormat = .a4
        return try await client.pdf(opts)
    }

    /// Extract article content for offline reading.
    func extractArticle(url: String) async throws -> ExtractResult {
        return try await client.extractArticle(url: url)
    }

    /// Check remaining API quota.
    func checkQuota() async throws -> QuotaResult {
        return try await client.quota()
    }
}

// MARK: - Usage in a SwiftUI ViewModel

/// Example ViewModel showing SnapAPI integration with SwiftUI.
///
/// ```swift
/// struct ContentView: View {
///     @StateObject private var viewModel = ScreenshotViewModel()
///
///     var body: some View {
///         VStack {
///             if let imageData = viewModel.imageData {
///                 // Display the image
///             }
///             Button("Capture") {
///                 Task { await viewModel.capture(url: "https://example.com") }
///             }
///         }
///     }
/// }
/// ```
@MainActor
final class ScreenshotViewModel: ObservableObject {
    @Published var imageData: Data?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service: ScreenshotService

    init(apiKey: String = ProcessInfo.processInfo.environment["SNAPAPI_KEY"] ?? "sk_your_key") {
        self.service = ScreenshotService(apiKey: apiKey)
    }

    func capture(url: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            imageData = try await service.captureScreenshot(url: url)
        } catch let error as SnapAPIError {
            switch error {
            case .rateLimited(let retryAfter):
                errorMessage = "Rate limited. Try again in \(Int(retryAfter))s."
            case .quotaExceeded:
                errorMessage = "API quota exceeded. Please upgrade your plan."
            case .unauthorized:
                errorMessage = "Invalid API key. Check your configuration."
            default:
                errorMessage = error.localizedDescription
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
