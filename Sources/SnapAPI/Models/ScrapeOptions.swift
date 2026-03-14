import Foundation

// MARK: - ScrapeOptions

/// Parameters for `POST /v1/scrape`.
///
/// ```swift
/// var opts = ScrapeOptions(url: "https://example.com")
/// opts.selector = "article"
/// opts.wait     = 1000
/// ```
public struct ScrapeOptions: Encodable, Sendable {

    /// The URL to scrape. Required.
    public var url: String

    /// CSS selector — only return content matching this element.
    public var selector: String?

    /// Wait in milliseconds for dynamic content to load.
    public var wait: Int?

    /// Number of paginated pages to scrape (max 10).
    public var pages: Int?

    /// Proxy URL.
    public var proxy: String?

    /// Use a premium residential proxy.
    public var premiumProxy: Bool?

    /// Block images, fonts, and other non-essential resources.
    public var blockResources: Bool?

    /// Browser locale (e.g. `"en-US"`).
    public var locale: String?

    // MARK: Init

    /// Create a scrape options object.
    /// - Parameter url: The URL to scrape.
    public init(url: String) {
        self.url = url
    }
}

// MARK: - ScrapeResult

/// The response from `POST /v1/scrape`.
public struct ScrapeResult: Decodable, Sendable {
    /// Whether the request succeeded.
    public let success: Bool
    /// One item per scraped page.
    public let results: [ScrapeItem]
}

/// A single scraped page.
public struct ScrapeItem: Decodable, Sendable {
    /// 1-based page number.
    public let page: Int
    /// The URL that was scraped.
    public let url: String
    /// The scraped content (text, HTML, or links depending on request type).
    public let data: String
}
