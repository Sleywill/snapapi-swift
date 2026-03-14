import Foundation

// MARK: - PDFPageFormat

/// Paper size for PDF generation.
public enum PDFPageFormat: String, Codable, Sendable, CaseIterable {
    case a4     = "a4"
    case letter = "letter"
    case a3     = "a3"
    case a5     = "a5"
    case legal  = "legal"
    case tabloid = "tabloid"
}

// MARK: - PDFPageOptions

/// PDF-specific layout options used inside ``ScreenshotOptions/pdf``.
public struct PDFPageOptions: Codable, Sendable {

    /// Paper size. Defaults to `"a4"` server-side.
    public var pageSize: PDFPageFormat?

    /// Render in landscape orientation.
    public var landscape: Bool?

    /// Top margin (CSS value, e.g. `"1cm"`, `"10px"`).
    public var marginTop: String?

    /// Right margin.
    public var marginRight: String?

    /// Bottom margin.
    public var marginBottom: String?

    /// Left margin.
    public var marginLeft: String?

    public init(
        pageSize: PDFPageFormat? = nil,
        landscape: Bool? = nil,
        marginTop: String? = nil,
        marginRight: String? = nil,
        marginBottom: String? = nil,
        marginLeft: String? = nil
    ) {
        self.pageSize     = pageSize
        self.landscape    = landscape
        self.marginTop    = marginTop
        self.marginRight  = marginRight
        self.marginBottom = marginBottom
        self.marginLeft   = marginLeft
    }
}

// MARK: - PdfOptions (standalone)

/// Parameters for `POST /v1/pdf`.
///
/// ```swift
/// var opts = PdfOptions(url: "https://example.com")
/// opts.pageFormat = .letter
/// opts.landscape  = true
/// ```
public struct PdfOptions: Encodable, Sendable {

    /// The URL to render as PDF. Required.
    public var url: String

    /// Paper size. Defaults to `"a4"` server-side.
    public var pageFormat: PDFPageFormat?

    /// Top margin CSS value.
    public var margin: String?

    /// Render in landscape orientation.
    public var landscape: Bool?

    /// Wait in milliseconds for dynamic content.
    public var wait: Int?

    public init(url: String) {
        self.url = url
    }
}
