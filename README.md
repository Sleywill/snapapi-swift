# SnapAPI Swift SDK

[![Swift 5.9+](https://img.shields.io/badge/Swift-5.9+-F05138?style=flat-square&logo=swift&logoColor=white)](https://swift.org)
[![SPM](https://img.shields.io/badge/Swift%20Package%20Manager-compatible-FA7343?style=flat-square)](https://swift.org/package-manager/)
[![CI](https://github.com/Sleywill/snapapi-swift/actions/workflows/ci.yml/badge.svg)](https://github.com/Sleywill/snapapi-swift/actions)
[![License](https://img.shields.io/badge/License-MIT-blue?style=flat-square)](LICENSE)

Official Swift SDK for [SnapAPI.pics](https://snapapi.pics) — screenshot, scrape, extract, analyze, PDF, and video as a service.

**v3.1.0** — Actor-based, strict concurrency, zero third-party dependencies.

## Requirements

| Platform | Minimum |
|----------|---------|
| macOS    | 13.0    |
| iOS      | 16.0    |
| watchOS  | 9.0     |
| tvOS     | 16.0    |
| Swift    | 5.9     |

## Installation

### Swift Package Manager (Package.swift)

```swift
dependencies: [
    .package(url: "https://github.com/Sleywill/snapapi-swift", from: "3.1.0")
],
targets: [
    .target(name: "YourTarget", dependencies: [
        .product(name: "SnapAPI", package: "snapapi-swift")
    ])
]
```

### Xcode

**File > Add Package Dependencies**, enter:

```
https://github.com/Sleywill/snapapi-swift
```

Select **Up to Next Major Version** from `3.1.0`.

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

// Usage
let q = try await client.getUsage()
print("Used: \(q.used) / \(q.total)")
```

## Endpoints

### Screenshot — `POST /v1/screenshot`

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
let png  = try await client.screenshot(ScreenshotOptions(html: "<h1>Hello</h1>"))
let png2 = try await client.screenshot(ScreenshotOptions(markdown: "# Hello World"))
```

Save directly to a file:

```swift
let bytes = try await client.screenshotToFile(
    ScreenshotOptions(url: "https://example.com"),
    path: URL(fileURLWithPath: "output.png")
)
print("Wrote \(bytes) bytes")
```

Upload result to configured storage:

```swift
let result = try await client.screenshotToStorage(
    ScreenshotOptions(url: "https://example.com")
)
print("Stored at: \(result.url)")
```

#### All ScreenshotOptions

| Property             | Type                | Description |
|----------------------|---------------------|-------------|
| `url`                | `String?`           | URL to capture (one of url/html/markdown required) |
| `html`               | `String?`           | Raw HTML to render |
| `markdown`           | `String?`           | Markdown to render |
| `format`             | `ScreenshotFormat?` | `.png` `.jpeg` `.webp` `.avif` `.pdf` |
| `quality`            | `Int?`              | JPEG/WEBP quality 0–100 |
| `width`              | `Int?`              | Viewport width in pixels |
| `height`             | `Int?`              | Viewport height in pixels |
| `device`             | `String?`           | Device emulation (e.g. `"iPhone 14 Pro"`) |
| `fullPage`           | `Bool?`             | Capture full scrollable page |
| `selector`           | `String?`           | CSS selector to capture |
| `delay`              | `Int?`              | Delay before capture (ms) |
| `timeout`            | `Int?`              | Navigation timeout (ms) |
| `waitUntil`          | `String?`           | `"load"` `"networkidle"` etc. |
| `waitForSelector`    | `String?`           | CSS selector to wait for |
| `darkMode`           | `Bool?`             | Enable dark mode |
| `css`                | `String?`           | CSS to inject |
| `javascript`         | `String?`           | JavaScript to execute |
| `hideSelectors`      | `[String]?`         | CSS selectors to hide |
| `clickSelector`      | `String?`           | CSS selector to click |
| `blockAds`           | `Bool?`             | Block ad networks |
| `blockTrackers`      | `Bool?`             | Block analytics trackers |
| `blockCookieBanners` | `Bool?`             | Block cookie-consent banners |
| `userAgent`          | `String?`           | Override User-Agent |
| `extraHeaders`       | `[String: String]?` | Extra HTTP headers |
| `cookies`            | `[SnapCookie]?`     | Cookies to inject |
| `httpAuth`           | `HTTPAuth?`         | HTTP Basic Auth |
| `proxy`              | `String?`           | Proxy URL |
| `premiumProxy`       | `Bool?`             | Use residential proxy |
| `geolocation`        | `Geolocation?`      | GPS location emulation |
| `timezone`           | `String?`           | IANA timezone |
| `webhookUrl`         | `String?`           | Webhook URL for async notify |

### PDF — `POST /v1/pdf`

```swift
var opts = PdfOptions(url: "https://example.com")
opts.pageFormat = .a4       // .a4 | .letter | .a3 | .a5 | .legal | .tabloid
opts.landscape  = false
opts.wait       = 1000

let pdfBytes = try await client.pdf(opts)
```

Generate PDF from a screenshot options object:

```swift
let pdfData = try await client.pdfFromScreenshot(
    ScreenshotOptions(url: "https://example.com")
)
```

### Scrape — `POST /v1/scrape`

```swift
var opts = ScrapeOptions(url: "https://example.com")
opts.selector = "article"
opts.wait     = 1000        // ms to wait for dynamic content
opts.pages    = 3           // scrape up to 3 paginated pages

let result = try await client.scrape(opts)
for item in result.results {
    print("Page \(item.page): \(item.data)")
}
```

### Extract — `POST /v1/extract`

Convenience wrappers cover the most common formats:

```swift
let markdown = try await client.extractMarkdown(url: "https://example.com")
let article  = try await client.extractArticle(url: "https://example.com")
let text     = try await client.extractText(url: "https://example.com")
let links    = try await client.extractLinks(url: "https://example.com")
let images   = try await client.extractImages(url: "https://example.com")
let metadata = try await client.extractMetadata(url: "https://example.com")
```

Full control:

```swift
var opts = ExtractOptions(url: "https://example.com")
opts.format    = .markdown
opts.maxLength = 4096
opts.selector  = "article"
opts.blockAds  = true
let result = try await client.extract(opts)
```

Available formats: `.markdown` `.text` `.html` `.article` `.links` `.images` `.metadata` `.structured`

### Analyze — `POST /v1/analyze`

Uses an LLM provider to analyze webpage content. This endpoint may return
HTTP 503 when LLM credits are exhausted on the server.

```swift
var opts = AnalyzeOptions(url: "https://example.com")
opts.prompt   = "Summarize the main points of this page"
opts.provider = .openai    // .openai | .anthropic | .google

let result = try await client.analyze(opts)
print(result.result)
```

### Video — `POST /v1/video`

```swift
var opts = VideoOptions(url: "https://example.com")
opts.format   = .mp4
opts.duration = 5000       // ms
opts.fullPage = true
opts.fps      = 30

// Raw binary data
let videoBytes = try await client.video(opts)

// Structured JSON with metadata
let result = try await client.videoResult(opts)
print("Format: \(result.format.rawValue), Size: \(result.size) bytes")
let videoData = Data(base64Encoded: result.data)!
```

### Usage — `GET /v1/usage`

```swift
let usage = try await client.getUsage()
print("Used: \(usage.used) / \(usage.total) — \(usage.remaining) remaining")
if let resetsAt = usage.resetAt {
    print("Resets at: \(resetsAt)")
}
```

### Quota — `GET /v1/quota`

```swift
let quota = try await client.quota()
print("Quota: \(quota.used)/\(quota.total)")
```

### Ping — `GET /v1/ping`

```swift
let pong = try await client.ping()
print("Status: \(pong.status)")   // "ok"
print("Timestamp: \(pong.timestamp)")
```

## Error Handling

All methods throw `SnapAPIError`:

```swift
do {
    let data = try await client.screenshot(opts)
} catch SnapAPIError.authenticationFailed {
    // Invalid or revoked API key (HTTP 401/403)
} catch SnapAPIError.rateLimited(let retryAfter) {
    // Respect the server's retry window (HTTP 429)
    try await Task.sleep(for: .seconds(retryAfter))
} catch SnapAPIError.quotaExceeded {
    // Upgrade plan at snapapi.pics/dashboard (HTTP 402)
} catch SnapAPIError.serverError(let statusCode, let message) {
    print("Server error \(statusCode): \(message)")
} catch SnapAPIError.networkError(let underlying) {
    print("Network: \(underlying.localizedDescription)")
} catch SnapAPIError.invalidParameters(let msg) {
    print("Bad params: \(msg)")
} catch SnapAPIError.decodingError(let underlying) {
    print("Decoding failed: \(underlying)")
}
```

### SnapAPIError cases

| Case | Trigger | Retryable |
|------|---------|-----------|
| `.authenticationFailed` | HTTP 401 or 403 | No |
| `.rateLimited(retryAfter:)` | HTTP 429 | Yes |
| `.quotaExceeded` | HTTP 402 | No |
| `.serverError(statusCode:message:)` | HTTP 5xx | Yes (5xx only) |
| `.networkError(underlying:)` | DNS/TLS/timeout | Yes |
| `.invalidParameters(_)` | Missing required field | No |
| `.decodingError(underlying:)` | Unexpected response shape | No |

## Retry Policy

The client retries transient errors (rate limits, 5xx responses, network failures)
with exponential backoff. The `Retry-After` header is always respected.

```swift
// Custom policy: 5 retries, 2s initial delay, max 60s
let client = SnapAPIClient(
    apiKey: "sk_...",
    retryPolicy: RetryPolicy(
        maxAttempts: 5,
        baseDelay: 2.0,
        maxDelay: 60.0
    )
)

// Disable retries entirely
let strict = SnapAPIClient(apiKey: "sk_...", retryPolicy: .never)
```

## Thread Safety

`SnapAPIClient` is an `actor`. You can share a single instance across your entire
app without any additional locking:

```swift
// Define once at app level
let snapClient = SnapAPIClient(apiKey: "sk_...")

// Concurrent requests from any Swift task
async let a = snapClient.screenshot(optsA)
async let b = snapClient.screenshot(optsB)
let (imgA, imgB) = try await (a, b)
```

## iOS Integration

```swift
import SnapAPI
import SwiftUI

@MainActor
final class ScreenshotViewModel: ObservableObject {
    @Published var imageData: Data?
    @Published var error: String?

    private let client = SnapAPIClient(apiKey: "sk_...")

    func capture(url: String) async {
        do {
            var opts = ScreenshotOptions(url: url)
            opts.device   = "iPhone 14 Pro"
            opts.blockAds = true
            imageData = try await client.screenshot(opts)
        } catch {
            self.error = error.localizedDescription
        }
    }
}
```

## macOS Automation

```swift
import SnapAPI
import Foundation

let client = SnapAPIClient(apiKey: ProcessInfo.processInfo.environment["SNAPAPI_KEY"]!)

// Batch screenshot multiple URLs concurrently
let urls = ["https://example.com", "https://swift.org", "https://apple.com"]

try await withThrowingTaskGroup(of: (String, Data).self) { group in
    for url in urls {
        group.addTask {
            let data = try await client.screenshot(ScreenshotOptions(url: url))
            return (url, data)
        }
    }
    for try await (url, data) in group {
        let filename = "\(URL(string: url)!.host ?? "site").png"
        try data.write(to: URL(fileURLWithPath: filename))
        print("Saved \(filename) (\(data.count) bytes)")
    }
}
```

## Testing

Inject a mock `URLSession` configured with `URLProtocol` to test without network calls:

```swift
import XCTest
@testable import SnapAPI

final class MockURLProtocol: URLProtocol {
    static var response: (statusCode: Int, data: Data) = (200, Data())

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let r = Self.response
        let httpResponse = HTTPURLResponse(
            url: request.url!, statusCode: r.statusCode,
            httpVersion: nil, headerFields: nil
        )!
        client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: r.data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

func makeTestClient() -> SnapAPIClient {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    return SnapAPIClient(
        apiKey: "sk_test",
        session: URLSession(configuration: config),
        retryPolicy: .never
    )
}
```

Run tests:

```bash
swift test
```

## Examples

See the `Examples/` directory for complete working examples:

- **BasicExample.swift** — Quickstart covering all endpoints
- **iOSExample.swift** — SwiftUI integration with ViewModel pattern
- **macOSMonitor.swift** — Automated website monitoring tool

## Base URL

All requests go to `https://api.snapapi.pics`. To override (e.g., for a local proxy):

```swift
let client = SnapAPIClient(
    apiKey: "sk_...",
    baseURL: URL(string: "https://staging.api.snapapi.pics")!
)
```

## License

MIT. See [LICENSE](LICENSE).
