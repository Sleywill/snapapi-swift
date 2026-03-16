# SnapAPI Swift SDK

[![Swift 5.9+](https://img.shields.io/badge/Swift-5.9+-F05138?style=flat-square&logo=swift&logoColor=white)](https://swift.org)
[![SPM](https://img.shields.io/badge/Swift%20Package%20Manager-compatible-FA7343?style=flat-square)](https://swift.org/package-manager/)
[![CI](https://github.com/Sleywill/snapapi-swift/actions/workflows/ci.yml/badge.svg)](https://github.com/Sleywill/snapapi-swift/actions)
[![License](https://img.shields.io/badge/License-MIT-blue?style=flat-square)](LICENSE)

Official Swift SDK for [SnapAPI.pics](https://snapapi.pics) -- screenshot, scrape, extract, analyze, and PDF generation as a service.

**v3.0.0** -- Actor-based, strict concurrency, zero third-party dependencies.

## Requirements

| Platform | Minimum |
|----------|---------|
| macOS    | 12.0    |
| iOS      | 15.0    |
| watchOS  | 8.0     |
| tvOS     | 15.0    |
| Swift    | 5.9     |

## Installation

### Swift Package Manager

```swift
// Package.swift
.package(url: "https://github.com/Sleywill/snapapi-swift", from: "3.0.0")
```

Or via Xcode: **File > Add Package Dependencies**, enter the repository URL.

## Quickstart

```swift
import SnapAPI

let client = SnapAPIClient(apiKey: "sk_your_key")

// Screenshot
let png = try await client.screenshot(ScreenshotOptions(url: "https://example.com"))

// Screenshot to file
try await client.screenshotToFile(
    ScreenshotOptions(url: "https://example.com"),
    path: URL(fileURLWithPath: "shot.png")
)

// Scrape
let page = try await client.scrape(ScrapeOptions(url: "https://example.com"))
print(page.results.first?.data ?? "")

// Extract as Markdown
let md = try await client.extractMarkdown(url: "https://example.com")

// PDF
let pdfData = try await client.pdf(PdfOptions(url: "https://example.com"))

// Analyze (LLM-powered)
var analyzeOpts = AnalyzeOptions(url: "https://example.com")
analyzeOpts.prompt = "Summarize this page"
let analysis = try await client.analyze(analyzeOpts)

// Usage / Quota
let q = try await client.getUsage()
print("Used: \(q.used) / \(q.total)")
```

## Endpoints

### Screenshot -- `POST /v1/screenshot`

```swift
var opts = ScreenshotOptions(url: "https://example.com")
opts.format   = .png        // .png | .jpeg | .webp | .avif | .pdf
opts.fullPage = true
opts.width    = 1440
opts.darkMode = true
opts.blockAds = true

let imageData = try await client.screenshot(opts)
try imageData.write(to: URL(fileURLWithPath: "shot.png"))
```

Capture from raw HTML or Markdown:

```swift
let png = try await client.screenshot(ScreenshotOptions(html: "<h1>Hello</h1>"))
```

Save directly to a file:

```swift
let bytes = try await client.screenshotToFile(
    ScreenshotOptions(url: "https://example.com"),
    path: URL(fileURLWithPath: "output.png")
)
print("Wrote \(bytes) bytes")
```

### PDF -- `POST /v1/pdf`

```swift
var opts = PdfOptions(url: "https://example.com")
opts.pageFormat = .a4       // .a4 | .letter | .a3 | .legal | .tabloid
opts.landscape  = false

let pdfBytes = try await client.pdf(opts)
```

### Scrape -- `POST /v1/scrape`

```swift
var opts = ScrapeOptions(url: "https://example.com")
opts.selector = "article"
opts.wait     = 1000        // ms to wait for dynamic content

let result = try await client.scrape(opts)
for item in result.results {
    print("Page \(item.page): \(item.data)")
}
```

### Extract -- `POST /v1/extract`

```swift
// Convenience wrappers
let markdown = try await client.extractMarkdown(url: "https://example.com")
let article  = try await client.extractArticle(url: "https://example.com")
let text     = try await client.extractText(url: "https://example.com")
let links    = try await client.extractLinks(url: "https://example.com")
let images   = try await client.extractImages(url: "https://example.com")
let metadata = try await client.extractMetadata(url: "https://example.com")

// Full control
var opts = ExtractOptions(url: "https://example.com")
opts.format    = .markdown
opts.maxLength = 4096
let result = try await client.extract(opts)
```

### Analyze -- `POST /v1/analyze`

Uses an LLM provider to analyze webpage content. This endpoint may return
HTTP 503 when LLM credits are exhausted on the server.

```swift
var opts = AnalyzeOptions(url: "https://example.com")
opts.prompt   = "Summarize the main points of this page"
opts.provider = .openai

let result = try await client.analyze(opts)
print(result.result)
```

### Usage -- `GET /v1/usage`

```swift
let usage = try await client.getUsage()
print("Used: \(usage.used) / \(usage.total) -- \(usage.remaining) remaining")
```

## Error Handling

All methods throw `SnapAPIError`:

```swift
do {
    let data = try await client.screenshot(opts)
} catch SnapAPIError.unauthorized {
    // Invalid or revoked API key
} catch SnapAPIError.rateLimited(let retryAfter) {
    // Respect the server's retry window
    try await Task.sleep(for: .seconds(retryAfter))
} catch SnapAPIError.quotaExceeded {
    // Upgrade plan at snapapi.pics/dashboard
} catch SnapAPIError.serverError(let statusCode, let message) {
    print("Server error \(statusCode): \(message)")
} catch SnapAPIError.networkError(let underlying) {
    print("Network: \(underlying.localizedDescription)")
} catch SnapAPIError.invalidParameters(let msg) {
    print("Bad params: \(msg)")
}
```

## Retry Policy

The client retries transient errors (rate limits, 5xx responses, network failures)
with exponential backoff. The `Retry-After` header is always respected.

```swift
// Custom policy
let client = SnapAPIClient(
    apiKey: "sk_...",
    retryPolicy: RetryPolicy(
        maxAttempts: 5,
        baseDelay: 2.0,   // seconds for first retry
        maxDelay: 60.0    // maximum wait per attempt
    )
)

// Disable retries
let strict = SnapAPIClient(apiKey: "sk_...", retryPolicy: .never)
```

## Thread Safety

`SnapAPIClient` is an `actor`. You can share a single instance across your entire
app without any additional locking:

```swift
// Defined once at app level
let snapClient = SnapAPIClient(apiKey: "sk_...")

// Called concurrently from any task
async let a = snapClient.screenshot(optsA)
async let b = snapClient.screenshot(optsB)
let (imgA, imgB) = try await (a, b)
```

## iOS Use Cases

Capture website screenshots in your iOS app:

```swift
// In a SwiftUI view model
@MainActor
class ViewModel: ObservableObject {
    @Published var imageData: Data?
    private let client = SnapAPIClient(apiKey: "sk_...")

    func capture(url: String) async {
        var opts = ScreenshotOptions(url: url)
        opts.device = "iPhone 14 Pro"
        opts.blockAds = true
        imageData = try? await client.screenshot(opts)
    }
}
```

## macOS Use Cases

Automated screenshot monitoring:

```swift
// Periodic website capture for visual regression
let urls = ["https://example.com", "https://competitor.com"]
for url in urls {
    let data = try await client.screenshot(ScreenshotOptions(url: url))
    let filename = "\(url.host ?? "site")_\(Date().timeIntervalSince1970).png"
    try data.write(to: URL(fileURLWithPath: filename))
}
```

## Testing

Inject a mock `URLSession` to test without network calls:

```swift
let session = MockURLSession(statusCode: 200, data: fakeResponseData)
let client  = SnapAPIClient(apiKey: "test", session: session, retryPolicy: .never)
```

Run tests:

```bash
swift test
```

## Examples

See the `Examples/` directory for complete working examples:

- **BasicExample.swift** -- Quickstart covering all endpoints
- **iOSExample.swift** -- SwiftUI integration with ViewModel pattern
- **macOSMonitor.swift** -- Automated website monitoring tool

## License

MIT. See [LICENSE](LICENSE).
