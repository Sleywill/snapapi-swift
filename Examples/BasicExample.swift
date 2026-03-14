// BasicExample.swift
// Demonstrates common SnapAPI Swift SDK usage patterns.
//
// To run: add this file to a Command-line tool Xcode target, or use a
// Swift package executable target.
//
// Environment variable: SNAPAPI_KEY=sk_your_key

import Foundation
import SnapAPI

@main
struct BasicExample {
    static func main() async {
        let apiKey = ProcessInfo.processInfo.environment["SNAPAPI_KEY"] ?? "sk_your_key"
        let client = SnapAPIClient(apiKey: apiKey)

        do {
            try await runExamples(client: client)
        } catch SnapAPIError.unauthorized {
            print("ERROR: invalid API key — set SNAPAPI_KEY environment variable")
        } catch SnapAPIError.rateLimited(let retryAfter) {
            print("ERROR: rate limited — retry after \(Int(retryAfter))s")
        } catch SnapAPIError.quotaExceeded {
            print("ERROR: quota exceeded — upgrade at snapapi.pics/dashboard")
        } catch SnapAPIError.serverError(let code, let msg) {
            print("ERROR: server error \(code): \(msg)")
        } catch {
            print("ERROR: \(error)")
        }
    }
}

private func runExamples(client: SnapAPIClient) async throws {

    // ── Quota check ────────────────────────────────────────────────────────
    let q = try await client.quota()
    print("Quota: \(q.used)/\(q.total) used (resets: \(q.resetAt ?? "unknown"))")

    // ── Screenshot ─────────────────────────────────────────────────────────
    print("\nTaking screenshot...")
    var screenshotOpts = ScreenshotOptions(url: "https://example.com")
    screenshotOpts.format   = .png
    screenshotOpts.fullPage = true
    screenshotOpts.width    = 1440

    let imageData = try await client.screenshot(screenshotOpts)
    try imageData.write(to: URL(fileURLWithPath: "screenshot.png"))
    print("Saved screenshot.png (\(imageData.count) bytes)")

    // ── PDF ────────────────────────────────────────────────────────────────
    print("\nGenerating PDF...")
    var pdfOpts = PdfOptions(url: "https://example.com")
    pdfOpts.pageFormat = .a4

    let pdfData = try await client.pdf(pdfOpts)
    try pdfData.write(to: URL(fileURLWithPath: "page.pdf"))
    print("Saved page.pdf (\(pdfData.count) bytes)")

    // ── Scrape ─────────────────────────────────────────────────────────────
    print("\nScraping...")
    var scrapeOpts    = ScrapeOptions(url: "https://example.com")
    scrapeOpts.selector = "body"

    let scrapeResult = try await client.scrape(scrapeOpts)
    for item in scrapeResult.results {
        let preview = String(item.data.prefix(80))
        print("  Page \(item.page): \(preview)...")
    }

    // ── Extract ────────────────────────────────────────────────────────────
    print("\nExtracting article...")
    let article = try await client.extractArticle(url: "https://example.com")
    print("  type=\(article.type)  responseTime=\(article.responseTime)ms")

    // ── Extract Markdown ───────────────────────────────────────────────────
    print("\nExtracting as Markdown...")
    let md = try await client.extractMarkdown(url: "https://example.com")
    if let text = md.data?.value as? String {
        print("  \(String(text.prefix(120)))...")
    }

    print("\nDone.")
}
