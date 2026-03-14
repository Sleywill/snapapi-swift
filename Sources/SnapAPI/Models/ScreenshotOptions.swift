import Foundation

// MARK: - Screenshot format

/// Output image format for a screenshot request.
public enum ScreenshotFormat: String, Codable, Sendable, CaseIterable {
    case png  = "png"
    case jpeg = "jpeg"
    case webp = "webp"
    case avif = "avif"
    case pdf  = "pdf"
}

// MARK: - ScreenshotOptions

/// Parameters for `POST /v1/screenshot`.
///
/// At least one of ``url``, ``html``, or ``markdown`` must be supplied.
///
/// ```swift
/// var opts = ScreenshotOptions(url: "https://example.com")
/// opts.format   = .png
/// opts.fullPage = true
/// opts.width    = 1440
/// ```
public struct ScreenshotOptions: Encodable, Sendable {

    // MARK: Source (one required)

    /// Public URL to capture.
    public var url: String?

    /// Raw HTML to render.
    public var html: String?

    /// Markdown to render.
    public var markdown: String?

    // MARK: Output

    /// Image format. Defaults to `png` server-side.
    public var format: ScreenshotFormat?

    /// JPEG/WEBP quality 0–100. Ignored for PNG.
    public var quality: Int?

    // MARK: Viewport

    /// Viewport width in pixels.
    public var width: Int?

    /// Viewport height in pixels.
    public var height: Int?

    /// Emulate a named device (e.g. `"iPhone 14 Pro"`).
    public var device: String?

    // MARK: Page behaviour

    /// Capture the full scrollable page height.
    public var fullPage: Bool?

    /// CSS selector — capture only the matching element.
    public var selector: String?

    /// Delay in milliseconds before capturing.
    public var delay: Int?

    /// Navigation timeout in milliseconds.
    public var timeout: Int?

    /// When to consider navigation finished (`"load"`, `"networkidle"`, etc.).
    public var waitUntil: String?

    /// Wait for this CSS selector to appear before capturing.
    public var waitForSelector: String?

    // MARK: Visual

    /// Enable dark mode media query.
    public var darkMode: Bool?

    // MARK: Scripting

    /// CSS to inject into the page.
    public var css: String?

    /// JavaScript to execute before capture.
    public var javascript: String?

    /// CSS selectors to hide before capture.
    public var hideSelectors: [String]?

    /// Click this CSS selector before capture.
    public var clickSelector: String?

    // MARK: Blocking

    /// Block ad networks.
    public var blockAds: Bool?

    /// Block analytics trackers.
    public var blockTrackers: Bool?

    /// Block cookie-consent banners.
    public var blockCookieBanners: Bool?

    // MARK: Identity / Auth

    /// Override the browser `User-Agent`.
    public var userAgent: String?

    /// Extra HTTP request headers to send.
    public var extraHeaders: [String: String]?

    /// Cookies to inject before navigation.
    public var cookies: [SnapCookie]?

    /// HTTP Basic Auth credentials.
    public var httpAuth: HTTPAuth?

    // MARK: Proxy

    /// Proxy URL (e.g. `"http://user:pass@host:port"`).
    public var proxy: String?

    /// Use a premium residential proxy.
    public var premiumProxy: Bool?

    // MARK: Environment

    /// Emulate a GPS location.
    public var geolocation: Geolocation?

    /// IANA timezone identifier (e.g. `"America/New_York"`).
    public var timezone: String?

    // MARK: PDF

    /// PDF layout options. Only used when ``format`` is `.pdf`.
    public var pdf: PDFPageOptions?

    // MARK: Storage / Webhooks

    /// Upload the result to configured storage.
    public var storage: StorageDestination?

    /// Webhook URL to notify when the screenshot is ready.
    public var webhookUrl: String?

    // MARK: Init

    /// Create a screenshot options object.
    ///
    /// - Parameters:
    ///   - url:      The URL to capture.
    ///   - html:     Raw HTML to render (alternative to `url`).
    ///   - markdown: Markdown to render (alternative to `url`).
    public init(url: String? = nil, html: String? = nil, markdown: String? = nil) {
        self.url      = url
        self.html     = html
        self.markdown = markdown
    }
}

// MARK: - StorageUploadResult

/// Returned by ``SnapAPIClient/screenshotToStorage(_:)`` when the API uploads
/// the result to the configured storage backend.
public struct StorageUploadResult: Decodable, Sendable {
    /// Unique identifier of the stored file.
    public let id: String
    /// Public URL of the stored file.
    public let url: String
}
