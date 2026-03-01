# snapapi-swift

Official Swift SDK for [SnapAPI](https://snapapi.pics) — lightning-fast screenshot, PDF, scrape, extract, and AI web analysis API.

## Requirements

- Swift 5.9+
- iOS 15+ / macOS 12+

## Installation

### Swift Package Manager

Add the dependency in `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/Sleywill/snapapi-swift.git", from: "2.0.0"),
],
targets: [
    .target(
        name: "MyApp",
        dependencies: [.product(name: "SnapAPI", package: "snapapi-swift")]
    ),
]
```

Or add it in Xcode: **File → Add Package Dependencies…** and enter the URL above.

## Quick Start

```swift
import SnapAPI

let api = SnapAPI(apiKey: "your-api-key")

// Take a screenshot
var opts = ScreenshotOptions(url: "https://example.com")
opts.format   = "png"
opts.fullPage = true

let imageData = try await api.screenshot(opts)
try imageData.write(to: URL(fileURLWithPath: "screenshot.png"))
```

## Authentication

```swift
let api = SnapAPI(apiKey: ProcessInfo.processInfo.environment["SNAPAPI_KEY"]!)
```

## Endpoints

### Screenshot — `POST /v1/screenshot`

```swift
// Basic PNG
var opts = ScreenshotOptions(url: "https://example.com")
opts.format = "png"
opts.width  = 1440
let data = try await api.screenshot(opts)

// Full-page dark mode
var opts2 = ScreenshotOptions(url: "https://example.com")
opts2.fullPage           = true
opts2.darkMode           = true
opts2.blockAds           = true
opts2.blockCookieBanners = true
let data2 = try await api.screenshot(opts2)

// From HTML
var htmlOpts = ScreenshotOptions(html: "<h1>Hello!</h1>")
htmlOpts.format = "png"
let data3 = try await api.screenshot(htmlOpts)

// Device emulation
var mobileOpts = ScreenshotOptions(url: "https://example.com")
mobileOpts.device = "iphone-15-pro"
let data4 = try await api.screenshot(mobileOpts)
```

### PDF — `POST /v1/screenshot` (format=pdf)

```swift
var opts = ScreenshotOptions(url: "https://example.com")
var pdfOpts = PDFPageOptions()
pdfOpts.pageSize  = "A4"
pdfOpts.landscape = false
opts.pdf = pdfOpts

let pdfData = try await api.pdf(opts)
```

### Screenshot to Storage

```swift
var opts = ScreenshotOptions(url: "https://example.com")
opts.storage = StorageDestination(destination: "s3")

let result = try await api.screenshotToStorage(opts)
print(result.url) // public URL
```

### Scrape — `POST /v1/scrape`

```swift
var opts = ScrapeOptions(url: "https://example.com")
opts.type  = "text"  // text|html|links
opts.pages = 3

let result = try await api.scrape(opts)
for page in result.results {
    print("Page \(page.page): \(page.url)")
}
```

### Extract — `POST /v1/extract`

```swift
// Quick helpers
let article  = try await api.extractArticle(url: "https://example.com/post")
let markdown = try await api.extractMarkdown(url: "https://example.com")
let links    = try await api.extractLinks(url: "https://example.com")
let images   = try await api.extractImages(url: "https://example.com")
let metadata = try await api.extractMetadata(url: "https://example.com")

// Full options
var opts = ExtractOptions(url: "https://example.com")
opts.type          = "structured"
opts.includeImages = true
opts.maxLength     = 5000
let result = try await api.extract(opts)
print("Response time: \(result.responseTime)ms")
```

### Analyze — `POST /v1/analyze`

```swift
var opts = AnalyzeOptions(url: "https://example.com")
opts.prompt            = "What is the main purpose of this page?"
opts.provider          = "openai"    // openai|anthropic
opts.apiKey            = "sk-..."    // your LLM API key
opts.includeScreenshot = true

let result = try await api.analyze(opts)
print(result.analysis?.value ?? "")
```

### Storage — `/v1/storage/*`

```swift
// List files
let files = try await api.listStorageFiles()

// Usage
let usage = try await api.storageUsage()
print("Used: \(usage.used) bytes")

// Configure S3
let config = S3Config(
    bucket: "my-bucket",
    region: "us-east-1",
    accessKeyId: "AKIA...",
    secretAccessKey: "..."
)
try await api.configureS3(config)

// Delete a file
try await api.deleteStorageFile(id: "file-id")
```

### Scheduled — `/v1/scheduled/*`

```swift
// Create hourly job
let job = try await api.createScheduled(
    ScheduledOptions(url: "https://example.com", cronExpression: "0 * * * *")
)
print("Next run: \(job.nextRunAt ?? "unknown")")

// List all
let jobs = try await api.listScheduled()

// Delete
try await api.deleteScheduled(id: job.id)
```

### Webhooks — `/v1/webhooks/*`

```swift
// Register
let hook = try await api.createWebhook(
    WebhookOptions(url: "https://myapp.com/snapapi", events: ["screenshot.completed"])
)

// List / delete
let hooks = try await api.listWebhooks()
try await api.deleteWebhook(id: hook.id)
```

### API Keys — `/v1/keys/*`

```swift
// List
let keys = try await api.listKeys()

// Create (key secret shown only once)
let key = try await api.createKey(name: "production")
print(key.key ?? "")

// Revoke
try await api.deleteKey(id: key.id)
```

## Error Handling

```swift
do {
    let data = try await api.screenshot(opts)
} catch SnapAPIError.apiError(let code, let message, let statusCode) {
    print("API error [\(code)]: \(message) (HTTP \(statusCode))")
    if case SnapAPIError.apiError = SnapAPIError.apiError(code: code, message: message, statusCode: statusCode),
       statusCode == 429 {
        // retry with exponential backoff
    }
} catch SnapAPIError.networkError(let err) {
    print("Network: \(err)")
} catch {
    print("Unknown: \(error)")
}
```

## License

MIT
