# Changelog

All notable changes to the SnapAPI Swift SDK will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [3.1.0] - 2026-03-17

### Added
- `Authorization: Bearer` header sent alongside `X-Api-Key` for maximum server compatibility
- `getUsage()` method targeting `GET /v1/usage` (distinct from `quota()`)
- `quota()` method targeting `GET /v1/quota` as a separate endpoint
- `fullPage` property added to `VideoOptions`
- `UsageResult` type (replacing `QuotaResult`); `QuotaResult` kept as a typealias
- `URLProtocol`-based mock infrastructure in tests — replaces broken `URLSession` subclassing approach
- `RequestBuilderTests` test suite covering all headers, HTTP methods, URL composition, and timeout
- `HTTPClientTests.testRetryOnNetworkFailure` verifying exponential backoff retry logic
- `HTTPClientTests.testDecodingErrorOnMalformedJSON` verifying decoding error path
- `HTTPClientTests.testSuccessfulPing`, `testSuccessfulScrape`, `testSuccessfulExtract`, `testSuccessfulQuotaDecoding`
- Additional `ModelTests` covering `AnyCodable` encode/decode round-trip, dynamic member lookup, literal conformances, options encoding, and `PDFPageOptions`
- `FailOnceURLProtocol` and `HeaderCapturingURLProtocol` test helpers

### Changed
- `SnapAPIError.unauthorized` renamed to `SnapAPIError.authenticationFailed` (matches spec)
- `SnapAPIError.networkError` associated value now has the label `underlying:` for clarity
- `SnapAPIError.decodingError` associated value now has the label `underlying:` for clarity
- Platform minimums bumped to macOS 13, iOS 16, watchOS 9, tvOS 16 (from macOS 12, iOS 15, watchOS 8, tvOS 15)
- User-Agent updated to `snapapi-swift/3.1.0`

### Fixed
- `MockURLSession` compilation error — Swift does not allow overriding `data(for:)` outside Foundation. Replaced with `URLProtocol`-based approach that compiles correctly on all platforms.
- Test helpers that used `value as? String` on `AnyCodable` now correctly pattern-match on `AnyJSON` cases.

## [3.0.0] - 2026-03-16

### Added
- Actor-based `SnapAPIClient` for built-in thread safety (Swift strict concurrency).
- `analyze()` method mapping to `POST /v1/analyze` with LLM provider support.
- `AnalyzeOptions` and `AnalyzeResult` models.
- `screenshotToFile()` convenience method to write screenshots directly to disk.
- `getUsage()` method mapping to `GET /v1/usage`.
- Dedicated `pdf()` method mapping to `POST /v1/pdf`.
- `SnapAPIError.unauthorized` — distinct case for 401/403 responses.
- `SnapAPIError.rateLimited(retryAfter: TimeInterval)` — carries the retry delay.
- `SnapAPIError.quotaExceeded` — distinct case for 402 responses.
- `SnapAPIError.serverError(statusCode: Int, message: String)` — replaces old `httpError`.
- `RetryPolicy` struct — configurable exponential backoff with `Retry-After` header support.
- `HTTPClient` actor — handles all HTTP execution with retry logic.
- `RequestBuilder` struct — centralised request construction.
- `X-Api-Key` authentication header matching the API specification.
- `SnapCookie` type renamed from `Cookie` to avoid standard library conflicts.
- `ScreenshotFormat`, `ExtractFormat`, `PDFPageFormat` typed enums replacing raw strings.
- `QuotaResult` response model.
- `PdfOptions` standalone options type.
- `SnapAPI` type alias for backwards compatibility with v2 code.
- MIT LICENSE file.
- `.gitignore` for Swift Package Manager and Xcode artifacts.
- GitHub Actions CI workflow.
- Comprehensive XCTest suite including HTTP-layer mock tests.
- iOS example with SwiftUI ViewModel pattern.
- macOS example for automated website monitoring.

### Changed
- `SnapAPI` class is now an `actor` (`SnapAPIClient`).
- Base URL set to `https://api.snapapi.pics`.
- Authentication uses `X-Api-Key` header (matching API specification).
- `ScrapeOptions.waitMs` renamed to `wait` to match API parameter name.
- `ExtractOptions.type` renamed to `format` (typed `ExtractFormat` enum).
- `ExtractOptions.waitFor` renamed to `wait`.
- Models split into individual files under `Sources/SnapAPI/Models/`.
- Networking split into `HTTPClient`, `RequestBuilder`, `RetryPolicy`.
- Error parsing moved to `Errors/SnapAPIError.swift`.
- `JSONEncoder` uses `.convertToSnakeCase` for correct wire format.
- `JSONDecoder` uses `.convertFromSnakeCase`.

### Removed
- `SnapAPIError.apiError(code:message:statusCode:)` — replaced by specific cases.
- `SnapAPIError.httpError(statusCode:body:)` — replaced by `serverError`.
- Storage, Scheduled, Webhook, and API Key management methods (not part of public v3 scope).

## [2.0.0] - 2025-01-01

### Added
- Initial async/await implementation.
- URLSession-based networking.
- Basic error handling.
