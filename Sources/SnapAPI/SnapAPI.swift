import Foundation

// MARK: - SnapAPIClient

/// Thread-safe SnapAPI client.
///
/// `SnapAPIClient` is an `actor`, so all calls are automatically serialised on
/// Swift's cooperative thread pool.  You can create a single shared instance
/// and call it from any Swift concurrency context.
///
/// ```swift
/// let client = SnapAPIClient(apiKey: "sk_your_key")
///
/// // Screenshot
/// let png = try await client.screenshot(ScreenshotOptions(url: "https://example.com"))
///
/// // Scrape
/// let page = try await client.scrape(ScrapeOptions(url: "https://example.com"))
///
/// // Extract
/// let md = try await client.extract(ExtractOptions(url: "https://news.ycombinator.com"))
///
/// // Usage
/// let q = try await client.getUsage()
/// print("Used: \(q.used) / \(q.total)")
/// ```
///
/// All methods throw ``SnapAPIError``. Handle errors with a typed `catch`:
///
/// ```swift
/// do {
///     let data = try await client.screenshot(opts)
/// } catch SnapAPIError.rateLimited(let retryAfter) {
///     print("Retry in \(retryAfter)s")
/// } catch SnapAPIError.quotaExceeded {
///     print("Upgrade your plan")
/// }
/// ```
public actor SnapAPIClient {

    // MARK: - Private state

    private let http: HTTPClient
    private let builder: RequestBuilder

    // MARK: - Init

    /// Create a SnapAPI client.
    ///
    /// - Parameters:
    ///   - apiKey:      Your SnapAPI key (starts with `sk_`).
    ///   - baseURL:     Override the API base URL. Useful for testing.
    ///   - session:     Override the `URLSession`. Useful for testing.
    ///   - retryPolicy: Retry behaviour for transient errors.
    public init(
        apiKey: String,
        baseURL: URL = URL(string: "https://api.snapapi.pics")!,
        session: URLSession = .shared,
        retryPolicy: RetryPolicy = .default
    ) {
        self.builder = RequestBuilder(baseURL: baseURL, apiKey: apiKey)
        self.http    = HTTPClient(session: session, retryPolicy: retryPolicy)
    }

    // MARK: - Screenshot  POST /v1/screenshot

    /// Capture a screenshot of a URL, HTML snippet, or Markdown string.
    ///
    /// Returns raw binary image data (PNG, JPEG, WEBP, AVIF) or PDF bytes.
    ///
    /// - Parameter options: At least one of `url`, `html`, or `markdown` must be set.
    /// - Returns: Binary image or PDF data.
    /// - Throws: ``SnapAPIError``
    public func screenshot(_ options: ScreenshotOptions) async throws -> Data {
        guard options.url != nil || options.html != nil || options.markdown != nil else {
            throw SnapAPIError.invalidParameters("One of url, html, or markdown is required.")
        }
        let req = try builder.post(path: "/v1/screenshot", body: options)
        return try await http.data(for: req)
    }

    /// Capture a screenshot and upload it to the configured storage backend.
    ///
    /// - Returns: ``StorageUploadResult`` containing the file `id` and public `url`.
    /// - Throws: ``SnapAPIError``
    public func screenshotToStorage(_ options: ScreenshotOptions) async throws -> StorageUploadResult {
        guard options.url != nil || options.html != nil || options.markdown != nil else {
            throw SnapAPIError.invalidParameters("One of url, html, or markdown is required.")
        }
        let req = try builder.post(path: "/v1/screenshot", body: options)
        return try await http.json(for: req)
    }

    /// Capture a screenshot and write it directly to a file.
    ///
    /// - Parameters:
    ///   - options: Screenshot options.
    ///   - fileURL: The local file URL to write the image data to.
    /// - Returns: The number of bytes written.
    /// - Throws: ``SnapAPIError``
    @discardableResult
    public func screenshotToFile(_ options: ScreenshotOptions, path fileURL: URL) async throws -> Int {
        let data = try await screenshot(options)
        try data.write(to: fileURL)
        return data.count
    }

    // MARK: - PDF  POST /v1/pdf

    /// Generate a PDF of a URL.
    ///
    /// ```swift
    /// var opts = PdfOptions(url: "https://example.com")
    /// opts.pageFormat = .a4
    /// let pdfData = try await client.pdf(opts)
    /// ```
    ///
    /// - Parameter options: PDF rendering options. `url` is required.
    /// - Returns: Raw PDF bytes.
    /// - Throws: ``SnapAPIError``
    public func pdf(_ options: PdfOptions) async throws -> Data {
        guard !options.url.isEmpty else {
            throw SnapAPIError.invalidParameters("url is required.")
        }
        let req = try builder.post(path: "/v1/pdf", body: options)
        return try await http.data(for: req)
    }

    /// Convenience: generate a PDF from a screenshot options object.
    ///
    /// Forces `format = .pdf` and calls `POST /v1/screenshot`.
    public func pdfFromScreenshot(_ options: ScreenshotOptions) async throws -> Data {
        guard options.url != nil || options.html != nil || options.markdown != nil else {
            throw SnapAPIError.invalidParameters("One of url, html, or markdown is required.")
        }
        var opts   = options
        opts.format = .pdf
        let req = try builder.post(path: "/v1/screenshot", body: opts)
        return try await http.data(for: req)
    }

    // MARK: - Scrape  POST /v1/scrape

    /// Scrape text, HTML, or links from a URL.
    ///
    /// ```swift
    /// var opts = ScrapeOptions(url: "https://example.com")
    /// opts.selector = "article"
    /// let result = try await client.scrape(opts)
    /// print(result.results.first?.data ?? "")
    /// ```
    ///
    /// - Parameter options: Scrape options. `url` is required.
    /// - Returns: ``ScrapeResult`` with one ``ScrapeItem`` per page.
    /// - Throws: ``SnapAPIError``
    public func scrape(_ options: ScrapeOptions) async throws -> ScrapeResult {
        guard !options.url.isEmpty else {
            throw SnapAPIError.invalidParameters("url is required.")
        }
        let req = try builder.post(path: "/v1/scrape", body: options)
        return try await http.json(for: req)
    }

    // MARK: - Extract  POST /v1/extract

    /// Extract structured content from a webpage.
    ///
    /// ```swift
    /// var opts = ExtractOptions(url: "https://techcrunch.com/some-article")
    /// opts.format = .markdown
    /// let result = try await client.extract(opts)
    /// ```
    ///
    /// - Parameter options: Extract options. `url` is required.
    /// - Returns: ``ExtractResult`` with the requested content.
    /// - Throws: ``SnapAPIError``
    public func extract(_ options: ExtractOptions) async throws -> ExtractResult {
        guard !options.url.isEmpty else {
            throw SnapAPIError.invalidParameters("url is required.")
        }
        let req = try builder.post(path: "/v1/extract", body: options)
        return try await http.json(for: req)
    }

    // MARK: - Extract convenience methods

    /// Extract page content as Markdown.
    public func extractMarkdown(url: String) async throws -> ExtractResult {
        var opts = ExtractOptions(url: url); opts.format = .markdown
        return try await extract(opts)
    }

    /// Extract article body text.
    public func extractArticle(url: String) async throws -> ExtractResult {
        var opts = ExtractOptions(url: url); opts.format = .article
        return try await extract(opts)
    }

    /// Extract plain text.
    public func extractText(url: String) async throws -> ExtractResult {
        var opts = ExtractOptions(url: url); opts.format = .text
        return try await extract(opts)
    }

    /// Extract all hyperlinks.
    public func extractLinks(url: String) async throws -> ExtractResult {
        var opts = ExtractOptions(url: url); opts.format = .links
        return try await extract(opts)
    }

    /// Extract all image URLs.
    public func extractImages(url: String) async throws -> ExtractResult {
        var opts = ExtractOptions(url: url); opts.format = .images
        return try await extract(opts)
    }

    /// Extract page metadata (Open Graph, meta tags).
    public func extractMetadata(url: String) async throws -> ExtractResult {
        var opts = ExtractOptions(url: url); opts.format = .metadata
        return try await extract(opts)
    }

    // MARK: - Analyze  POST /v1/analyze

    /// Analyze a webpage using an LLM provider.
    ///
    /// This endpoint extracts content from the URL and sends it to an LLM for
    /// analysis. It may return HTTP 503 when LLM credits are exhausted
    /// server-side.
    ///
    /// ```swift
    /// var opts = AnalyzeOptions(url: "https://example.com")
    /// opts.prompt   = "Summarize this page"
    /// opts.provider = .openai
    /// let result = try await client.analyze(opts)
    /// print(result.result)
    /// ```
    ///
    /// - Parameter options: Analyze options. `url` is required.
    /// - Returns: ``AnalyzeResult`` with the LLM analysis.
    /// - Throws: ``SnapAPIError``
    public func analyze(_ options: AnalyzeOptions) async throws -> AnalyzeResult {
        guard !options.url.isEmpty else {
            throw SnapAPIError.invalidParameters("url is required.")
        }
        let req = try builder.post(path: "/v1/analyze", body: options)
        return try await http.json(for: req)
    }

    // MARK: - Video  POST /v1/video

    /// Record a video of a live webpage.
    ///
    /// Returns raw binary video data. For structured metadata, use
    /// ``videoResult(_:)``.
    ///
    /// - Parameter options: Video options. `url` is required.
    /// - Returns: Raw video bytes.
    /// - Throws: ``SnapAPIError``
    public func video(_ options: VideoOptions) async throws -> Data {
        guard !options.url.isEmpty else {
            throw SnapAPIError.invalidParameters("url is required.")
        }
        var opts = options; opts.responseType = "binary"
        let req = try builder.post(path: "/v1/video", body: opts)
        return try await http.data(for: req)
    }

    /// Record a video and return structured metadata including a base64-encoded
    /// video payload.
    ///
    /// - Parameter options: Video options. `url` is required.
    /// - Returns: ``VideoResult`` with metadata and base64-encoded data.
    /// - Throws: ``SnapAPIError``
    public func videoResult(_ options: VideoOptions) async throws -> VideoResult {
        guard !options.url.isEmpty else {
            throw SnapAPIError.invalidParameters("url is required.")
        }
        var opts = options; opts.responseType = "json"
        let req = try builder.post(path: "/v1/video", body: opts)
        return try await http.json(for: req)
    }

    // MARK: - Usage  GET /v1/usage

    /// Fetch the account's API usage for the current billing period.
    ///
    /// ```swift
    /// let u = try await client.getUsage()
    /// print("Used: \(u.used) / \(u.total)  —  resets \(u.resetAt ?? "?")")
    /// ```
    ///
    /// - Returns: ``UsageResult`` with `used`, `total`, and `remaining` counts.
    /// - Throws: ``SnapAPIError``
    public func getUsage() async throws -> UsageResult {
        let req = builder.get(path: "/v1/usage")
        return try await http.json(for: req)
    }

    // MARK: - Quota  GET /v1/quota

    /// Fetch the account's quota summary for the current billing period.
    ///
    /// - Returns: ``UsageResult`` with `used`, `total`, and `remaining` counts.
    /// - Throws: ``SnapAPIError``
    public func quota() async throws -> UsageResult {
        let req = builder.get(path: "/v1/quota")
        return try await http.json(for: req)
    }

    // MARK: - Ping  GET /v1/ping

    /// Check API health.
    ///
    /// - Returns: ``PingResult`` with `status` and `timestamp`.
    /// - Throws: ``SnapAPIError``
    public func ping() async throws -> PingResult {
        let req = builder.get(path: "/v1/ping")
        return try await http.json(for: req)
    }
}

// MARK: - Backwards-compatible type alias

/// Type alias preserving the original `SnapAPI` name from v2.
///
/// New code should use ``SnapAPIClient``.
public typealias SnapAPI = SnapAPIClient
