# Changelog

All notable changes to the SnapAPI Swift SDK will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [3.1.0] - 2026-03-16

### Added
- `Authorization: Bearer` header sent alongside `X-Api-Key` for maximum server compatibility

### Changed
- API base URL corrected to `https://snapapi.pics` (was `https://api.snapapi.pics`)
- `getUsage()` is now the primary method (calls `GET /v1/usage`); `quota()` is the alias
- User-Agent updated to `snapapi-swift/3.1.0`

## [3.0.0] - 2026-03-16

### Added
- Actor-based `SnapAPIClient` for built-in thread safety (Swift strict concurrency).
- `analyze()` method mapping to `POST /v1/analyze` with LLM provider support.
- `AnalyzeOptions` and `AnalyzeResult` models.
- `screenshotToFile()` convenience method to write screenshots directly to disk.
- `getUsage()` method as alias for `quota()` matching `GET /v1/usage`.
- `quota()` method mapping to `GET /v1/quota`.
- Dedicated `pdf()` method mapping to `POST /v1/pdf`.
- `SnapAPIError.unauthorized` -- distinct case for 401/403 responses.
- `SnapAPIError.rateLimited(retryAfter: TimeInterval)` -- carries the retry delay.
- `SnapAPIError.quotaExceeded` -- distinct case for 402 responses.
- `SnapAPIError.serverError(statusCode: Int, message: String)` -- replaces old `httpError`.
- `RetryPolicy` struct -- configurable exponential backoff with `Retry-After` header support.
- `HTTPClient` actor -- handles all HTTP execution with retry logic.
- `RequestBuilder` struct -- centralised request construction.
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
- Base URL corrected to `https://api.snapapi.pics`.
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
- `SnapAPIError.apiError(code:message:statusCode:)` -- replaced by specific cases.
- `SnapAPIError.httpError(statusCode:body:)` -- replaced by `serverError`.
- Storage, Scheduled, Webhook, and API Key management methods (not part of public v3 scope).

## [2.0.0] - 2025-01-01

### Added
- Initial async/await implementation.
- URLSession-based networking.
- Basic error handling.
