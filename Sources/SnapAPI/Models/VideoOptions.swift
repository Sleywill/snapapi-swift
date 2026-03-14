import Foundation

// MARK: - VideoFormat

/// Output format for video recordings.
public enum VideoFormat: String, Codable, Sendable, CaseIterable {
    case webm = "webm"
    case mp4  = "mp4"
    case gif  = "gif"
}

// MARK: - ScrollEasing

/// Easing curve for automated scroll animations.
public enum ScrollEasing: String, Codable, Sendable, CaseIterable {
    case linear          = "linear"
    case easeIn          = "ease_in"
    case easeOut         = "ease_out"
    case easeInOut       = "ease_in_out"
    case easeInOutQuint  = "ease_in_out_quint"
}

// MARK: - VideoOptions

/// Parameters for `POST /v1/video`.
///
/// ```swift
/// var opts = VideoOptions(url: "https://example.com")
/// opts.format   = .mp4
/// opts.duration = 5000
/// opts.fullPage = true
/// ```
public struct VideoOptions: Encodable, Sendable {

    /// The URL to record. Required.
    public var url: String

    /// Output format. Defaults to `"mp4"` server-side.
    public var format: VideoFormat?

    /// Viewport width in pixels.
    public var width: Int?

    /// Viewport height in pixels.
    public var height: Int?

    /// Recording duration in milliseconds.
    public var duration: Int?

    /// Frames per second (1–60).
    public var fps: Int?

    // MARK: Scroll animation

    /// Enable automatic page scrolling during recording.
    public var scrolling: Bool?

    /// Scroll speed in pixels per second.
    public var scrollSpeed: Int?

    /// Delay before scrolling starts, in milliseconds.
    public var scrollDelay: Int?

    /// Total scroll animation duration in milliseconds.
    public var scrollDuration: Int?

    /// Pixels to scroll per step.
    public var scrollBy: Int?

    /// Easing curve for the scroll animation.
    public var scrollEasing: ScrollEasing?

    /// Scroll back to the top at the end.
    public var scrollBack: Bool?

    /// Wait for scroll to complete before stopping.
    public var scrollComplete: Bool?

    // MARK: Page options

    /// Enable dark mode.
    public var darkMode: Bool?

    /// Block ad networks.
    public var blockAds: Bool?

    /// Block cookie-consent banners.
    public var blockCookieBanners: Bool?

    /// Delay before recording starts, in milliseconds.
    public var delay: Int?

    // MARK: Response type (internal)

    /// Internal: `"binary"` or `"json"`. Set automatically by the SDK.
    var responseType: String?

    // MARK: Init

    /// Create a video options object.
    /// - Parameter url: The URL to record.
    public init(url: String) {
        self.url = url
    }
}

// MARK: - VideoResult

/// Returned by ``SnapAPIClient/videoResult(_:)`` with structured metadata.
public struct VideoResult: Decodable, Sendable {
    /// Base64-encoded video data.
    public let data: String
    /// MIME type (e.g. `"video/mp4"`).
    public let mimeType: String
    /// Output format.
    public let format: VideoFormat
    /// Video width in pixels.
    public let width: Int
    /// Video height in pixels.
    public let height: Int
    /// Duration in milliseconds.
    public let duration: Int
    /// File size in bytes.
    public let size: Int
}
