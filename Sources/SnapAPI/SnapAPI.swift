import Foundation

/// SnapAPI — Official Swift SDK
///
/// All methods are async and throw ``SnapAPIError``.
///
/// ```swift
/// let api = SnapAPI(apiKey: "your-api-key")
///
/// let imageData = try await api.screenshot(
///     ScreenshotOptions(url: "https://example.com")
/// )
/// ```
public final class SnapAPI {

    // MARK: - Configuration

    private let apiKey: String
    private let baseURL: URL
    private let session: URLSession

    private static let defaultBaseURL = URL(string: "https://api.snapapi.pics")!
    private static let userAgent      = "snapapi-swift/2.0.0"

    // MARK: - Init

    /// Create a SnapAPI client.
    /// - Parameters:
    ///   - apiKey:  Your SnapAPI key.
    ///   - baseURL: Override the base URL (useful for testing).
    ///   - session: Override the URLSession (useful for testing).
    public init(
        apiKey: String,
        baseURL: URL = SnapAPI.defaultBaseURL,
        session: URLSession = .shared
    ) {
        self.apiKey  = apiKey
        self.baseURL = baseURL
        self.session = session
    }

    // MARK: - Screenshot  POST /v1/screenshot

    /// Capture a screenshot.
    ///
    /// Returns raw PNG/JPEG/WEBP/AVIF/PDF bytes.
    /// When `options.storage` is set the API returns JSON; use
    /// ``screenshotToStorage(_:)`` instead.
    ///
    /// - Parameter options: Must have at least `url`, `html`, or `markdown`.
    /// - Returns: Binary image (or PDF) data.
    public func screenshot(_ options: ScreenshotOptions) async throws -> Data {
        guard options.url != nil || options.html != nil || options.markdown != nil else {
            throw SnapAPIError.invalidParameters("One of url, html, or markdown is required.")
        }
        return try await post(path: "/v1/screenshot", body: options)
    }

    /// Capture a screenshot and upload it to storage.
    ///
    /// - Returns: ``StorageUploadResult`` with `id` and `url`.
    public func screenshotToStorage(_ options: ScreenshotOptions) async throws -> StorageUploadResult {
        guard options.url != nil || options.html != nil || options.markdown != nil else {
            throw SnapAPIError.invalidParameters("One of url, html, or markdown is required.")
        }
        return try await postJSON(path: "/v1/screenshot", body: options)
    }

    /// Convenience: generate a PDF (forces `format = "pdf"`).
    public func pdf(_ options: ScreenshotOptions) async throws -> Data {
        var opts = options
        opts.format = "pdf"
        return try await screenshot(opts)
    }

    // MARK: - Scrape  POST /v1/scrape

    /// Scrape text, HTML, or links from a URL.
    ///
    /// - Parameter options: Must include `url`.
    /// - Returns: ``ScrapeResult`` with an array of page results.
    public func scrape(_ options: ScrapeOptions) async throws -> ScrapeResult {
        guard !options.url.isEmpty else {
            throw SnapAPIError.invalidParameters("url is required.")
        }
        return try await postJSON(path: "/v1/scrape", body: options)
    }

    // MARK: - Extract  POST /v1/extract

    /// Extract structured content from a webpage.
    ///
    /// - Parameter options: Must include `url`.
    /// - Returns: ``ExtractResult``.
    public func extract(_ options: ExtractOptions) async throws -> ExtractResult {
        guard !options.url.isEmpty else {
            throw SnapAPIError.invalidParameters("url is required.")
        }
        return try await postJSON(path: "/v1/extract", body: options)
    }

    /// Convenience: extract as Markdown.
    public func extractMarkdown(url: String) async throws -> ExtractResult {
        var opts = ExtractOptions(url: url); opts.type = "markdown"
        return try await extract(opts)
    }

    /// Convenience: extract article content.
    public func extractArticle(url: String) async throws -> ExtractResult {
        var opts = ExtractOptions(url: url); opts.type = "article"
        return try await extract(opts)
    }

    /// Convenience: extract plain text.
    public func extractText(url: String) async throws -> ExtractResult {
        var opts = ExtractOptions(url: url); opts.type = "text"
        return try await extract(opts)
    }

    /// Convenience: extract links.
    public func extractLinks(url: String) async throws -> ExtractResult {
        var opts = ExtractOptions(url: url); opts.type = "links"
        return try await extract(opts)
    }

    /// Convenience: extract images.
    public func extractImages(url: String) async throws -> ExtractResult {
        var opts = ExtractOptions(url: url); opts.type = "images"
        return try await extract(opts)
    }

    /// Convenience: extract metadata.
    public func extractMetadata(url: String) async throws -> ExtractResult {
        var opts = ExtractOptions(url: url); opts.type = "metadata"
        return try await extract(opts)
    }

    // MARK: - Analyze  POST /v1/analyze

    /// Perform AI-powered analysis of a webpage.
    ///
    /// - Parameter options: Must include `url`. Requires a provider API key.
    /// - Returns: ``AnalyzeResult`` with AI-generated analysis.
    public func analyze(_ options: AnalyzeOptions) async throws -> AnalyzeResult {
        guard !options.url.isEmpty else {
            throw SnapAPIError.invalidParameters("url is required.")
        }
        return try await postJSON(path: "/v1/analyze", body: options)
    }


    // MARK: - Video  POST /v1/video

    /// Record a video (WebM/MP4/GIF) of a live webpage.
    ///
    /// Returns raw binary `Data` when `options.responseType` is `nil` or `"binary"`.
    /// Use ``videoResult(_:)`` to get structured ``VideoResult`` metadata instead.
    ///
    /// - Parameter options: Must include `url`.
    /// - Returns: Binary video data.
    public func video(_ options: VideoOptions) async throws -> Data {
        guard !options.url.isEmpty else {
            throw SnapAPIError.invalidParameters("url is required.")
        }
        var opts = options
        opts.responseType = "binary"
        return try await post(path: "/v1/video", body: opts)
    }

    /// Record a video and return structured ``VideoResult`` metadata.
    public func videoResult(_ options: VideoOptions) async throws -> VideoResult {
        guard !options.url.isEmpty else {
            throw SnapAPIError.invalidParameters("url is required.")
        }
        var opts = options
        opts.responseType = "json"
        return try await postJSON(path: "/v1/video", body: opts)
    }

    // MARK: - Ping  GET /v1/ping

    /// Check API availability.
    ///
    /// - Returns: ``PingResult`` with `status` and `timestamp`.
    public func ping() async throws -> PingResult {
        return try await getJSON(path: "/v1/ping")
    }

    // MARK: - Account Usage  GET /v1/usage

    /// Get account-level API usage for the current billing period.
    ///
    /// - Returns: ``AccountUsage`` with `used`, `limit`, and `remaining`.
    public func usage() async throws -> AccountUsage {
        return try await getJSON(path: "/v1/usage")
    }

    // MARK: - Storage  /v1/storage/*

    /// List all stored files.
    public func listStorageFiles() async throws -> StorageFilesResult {
        try await getJSON(path: "/v1/storage/files")
    }

    /// Delete a stored file by ID.
    public func deleteStorageFile(id: String) async throws {
        try await delete(path: "/v1/storage/files/\(id)")
    }

    /// Get storage usage statistics.
    public func storageUsage() async throws -> StorageUsageResult {
        try await getJSON(path: "/v1/storage/usage")
    }

    /// Configure an S3-compatible storage backend.
    public func configureS3(_ config: S3Config) async throws {
        _ = try await post(path: "/v1/storage/s3", body: config)
    }

    /// Test the configured S3 connection.
    public func testS3() async throws {
        _ = try await postRaw(path: "/v1/storage/s3/test", body: Empty())
    }

    // MARK: - Scheduled  /v1/scheduled/*

    /// Create a scheduled screenshot job.
    public func createScheduled(_ options: ScheduledOptions) async throws -> ScheduledJob {
        try await postJSON(path: "/v1/scheduled", body: options)
    }

    /// List all scheduled jobs.
    public func listScheduled() async throws -> ScheduledListResult {
        try await getJSON(path: "/v1/scheduled")
    }

    /// Delete a scheduled job.
    public func deleteScheduled(id: String) async throws {
        try await delete(path: "/v1/scheduled/\(id)")
    }

    // MARK: - Webhooks  /v1/webhooks/*

    /// Register a new webhook.
    public func createWebhook(_ options: WebhookOptions) async throws -> Webhook {
        try await postJSON(path: "/v1/webhooks", body: options)
    }

    /// List all registered webhooks.
    public func listWebhooks() async throws -> WebhooksListResult {
        try await getJSON(path: "/v1/webhooks")
    }

    /// Delete a webhook.
    public func deleteWebhook(id: String) async throws {
        try await delete(path: "/v1/webhooks/\(id)")
    }

    // MARK: - API Keys  /v1/keys/*

    /// List all API keys.
    public func listKeys() async throws -> KeysListResult {
        try await getJSON(path: "/v1/keys")
    }

    /// Create a new API key.
    public func createKey(name: String) async throws -> APIKey {
        try await postJSON(path: "/v1/keys", body: ["name": name])
    }

    /// Revoke an API key.
    public func deleteKey(id: String) async throws {
        try await delete(path: "/v1/keys/\(id)")
    }

    // MARK: - HTTP internals

    private func buildRequest(method: String, path: String) -> URLRequest {
        var req = URLRequest(url: baseURL.appendingPathComponent(path))
        req.httpMethod = method
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(SnapAPI.userAgent, forHTTPHeaderField: "User-Agent")
        return req
    }

    private func execute(_ request: URLRequest) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw SnapAPIError.networkError(underlying: error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw SnapAPIError.httpError(statusCode: 0, body: "No HTTP response")
        }

        if http.statusCode >= 400 {
            throw parseAPIError(data: data, statusCode: http.statusCode)
        }
        return data
    }

    /// POST with Encodable body, returns raw Data.
    private func post<B: Encodable>(path: String, body: B) async throws -> Data {
        var req = buildRequest(method: "POST", path: path)
        req.httpBody = try JSONEncoder().encode(body)
        return try await execute(req)
    }

    /// POST with raw Data body.
    private func postRaw<B: Encodable>(path: String, body: B) async throws -> Data {
        try await post(path: path, body: body)
    }

    /// POST with Encodable body, decode response as R.
    private func postJSON<B: Encodable, R: Decodable>(path: String, body: B) async throws -> R {
        let data = try await post(path: path, body: body)
        return try decode(data)
    }

    /// GET, decode response as R.
    private func getJSON<R: Decodable>(path: String) async throws -> R {
        let req = buildRequest(method: "GET", path: path)
        let data = try await execute(req)
        return try decode(data)
    }

    /// DELETE (ignores response body).
    private func delete(path: String) async throws {
        let req = buildRequest(method: "DELETE", path: path)
        _ = try await execute(req)
    }

    private func decode<R: Decodable>(_ data: Data) throws -> R {
        do {
            return try JSONDecoder().decode(R.self, from: data)
        } catch {
            throw SnapAPIError.decodingError(underlying: error)
        }
    }
}

// Empty body for parameter-less POST requests.
private struct Empty: Encodable {}
