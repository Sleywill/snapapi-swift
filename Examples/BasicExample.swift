// BasicExample.swift
// Run: swift Examples/BasicExample.swift (not supported — paste into Xcode Playground or a Command-line tool target)

import Foundation
import SnapAPI

@main
struct BasicExample {
    static func main() async throws {
        let apiKey = ProcessInfo.processInfo.environment["SNAPAPI_KEY"] ?? "your-api-key"
        let api    = SnapAPI(apiKey: apiKey)

        // ── Screenshot ──────────────────────────────────────────────────────────
        print("Taking screenshot...")
        var screenshotOpts = ScreenshotOptions(url: "https://example.com")
        screenshotOpts.format   = "png"
        screenshotOpts.fullPage = true
        screenshotOpts.width    = 1280

        let imageData = try await api.screenshot(screenshotOpts)
        try imageData.write(to: URL(fileURLWithPath: "screenshot.png"))
        print("Saved screenshot.png (\(imageData.count) bytes)")

        // ── PDF ─────────────────────────────────────────────────────────────────
        print("Generating PDF...")
        var pdfOpts = ScreenshotOptions(url: "https://example.com")
        var pdfPage = PDFPageOptions(); pdfPage.pageSize = "A4"
        pdfOpts.pdf = pdfPage

        let pdfData = try await api.pdf(pdfOpts)
        try pdfData.write(to: URL(fileURLWithPath: "page.pdf"))
        print("Saved page.pdf (\(pdfData.count) bytes)")

        // ── Scrape ──────────────────────────────────────────────────────────────
        print("Scraping...")
        var scrapeOpts  = ScrapeOptions(url: "https://example.com")
        scrapeOpts.type = "text"

        let scrapeResult = try await api.scrape(scrapeOpts)
        for item in scrapeResult.results {
            print("Page \(item.page): \(item.data.prefix(60))...")
        }

        // ── Extract ─────────────────────────────────────────────────────────────
        print("Extracting article...")
        let article = try await api.extractArticle(url: "https://example.com")
        print("Extracted type=\(article.type) in \(article.responseTime)ms")

        // ── List Keys ───────────────────────────────────────────────────────────
        print("Listing API keys...")
        let keys = try await api.listKeys()
        for key in keys.keys {
            print("  \(key.name) (id=\(key.id))")
        }

        // ── Scheduled ───────────────────────────────────────────────────────────
        print("Creating scheduled job...")
        let job = try await api.createScheduled(
            ScheduledOptions(url: "https://example.com", cronExpression: "0 * * * *")
        )
        print("Created job id=\(job.id)")
        try await api.deleteScheduled(id: job.id)
        print("Deleted job.")

        print("\nDone!")
    }
}
