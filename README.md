# SnapAPI Swift SDK

[![Swift](https://img.shields.io/badge/Swift-5.9+-F05138?style=flat-square&logo=swift&logoColor=white)](https://swift.org)
[![SPM](https://img.shields.io/badge/Swift%20Package%20Manager-compatible-FA7343?style=flat-square)](https://swift.org/package-manager/)
[![License](https://img.shields.io/badge/License-MIT-blue?style=flat-square)](LICENSE)

Official Swift SDK for [SnapAPI](https://snapapi.pics) — screenshot, PDF generation, and web content extraction.

## Installation

### Swift Package Manager

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/Sleywill/snapapi-swift", from: "1.0.0")
]
```

Or in Xcode: **File → Add Package Dependencies** and enter the repo URL.

## Quick Start

```swift
import SnapAPI

let client = SnapAPIClient(apiKey: "your_api_key")

// Take a screenshot
let screenshot = try await client.screenshot(
    url: "https://example.com",
    options: .init(width: 1280, height: 800, format: .png)
)

// Generate a PDF
let pdf = try await client.pdf(
    url: "https://example.com",
    options: .init(format: .a4, landscape: false)
)
```

## Features

- 📸 **Screenshots** — Full page, viewport, or element-specific
- 📄 **PDF Generation** — With custom headers, footers, and page formats
- 🎬 **Video Capture** — Record page interactions
- 🔍 **Content Extraction** — Structured data from any web page
- 🤖 **AI Analysis** — Intelligent web content understanding

## Documentation

Full API documentation: [snapapi.pics/docs](https://snapapi.pics/docs)

## License

MIT © [Alex Serebriakov](https://github.com/Sleywill)
