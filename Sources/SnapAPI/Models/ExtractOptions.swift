import Foundation

// MARK: - ExtractFormat

/// Content format returned by the extract endpoint.
public enum ExtractFormat: String, Codable, Sendable, CaseIterable {
    /// Markdown representation of the page.
    case markdown   = "markdown"
    /// Plain text (no markup).
    case text       = "text"
    /// Raw HTML of the page or selected element.
    case html       = "html"
    /// Article body extracted from editorial content.
    case article    = "article"
    /// All hyperlinks found on the page.
    case links      = "links"
    /// All image URLs found on the page.
    case images     = "images"
    /// Open Graph / meta tags.
    case metadata   = "metadata"
    /// Structured JSON-LD or microdata.
    case structured = "structured"
}

// MARK: - ExtractOptions

/// Parameters for `POST /v1/extract`.
///
/// ```swift
/// var opts = ExtractOptions(url: "https://news.ycombinator.com")
/// opts.format = .markdown
/// opts.wait   = 500
/// ```
public struct ExtractOptions: Encodable, Sendable {

    /// The URL to extract content from. Required.
    public var url: String

    /// Format of the returned content. Defaults to `"markdown"` server-side.
    public var format: ExtractFormat?

    /// CSS selector — extract only content within this element.
    public var selector: String?

    /// Wait in milliseconds for dynamic content.
    public var wait: Int?

    /// Navigation timeout in milliseconds.
    public var timeout: Int?

    /// Enable dark mode.
    public var darkMode: Bool?

    /// Block ad networks.
    public var blockAds: Bool?

    /// Block cookie-consent banners.
    public var blockCookieBanners: Bool?

    /// Include image URLs in the output.
    public var includeImages: Bool?

    /// Truncate output to this many characters.
    public var maxLength: Int?

    // MARK: Init

    /// Create an extract options object.
    /// - Parameter url: The URL to extract content from.
    public init(url: String) {
        self.url = url
    }
}

// MARK: - ExtractResult

/// The response from `POST /v1/extract`.
public struct ExtractResult: Decodable, Sendable {
    /// Whether the request succeeded.
    public let success: Bool
    /// The format of the returned ``data``.
    public let type: String
    /// The URL that was processed.
    public let url: String
    /// Extracted content. The structure depends on the requested ``ExtractFormat``.
    public let data: AnyCodable?
    /// Server-side processing time in milliseconds.
    public let responseTime: Int
}
