import Foundation

// MARK: - Shared Types

public struct Cookie: Codable {
    public var name: String
    public var value: String
    public var domain: String?
    public var path: String?
    public var expires: Double?
    public var httpOnly: Bool?
    public var secure: Bool?
    public var sameSite: String?

    public init(name: String, value: String, domain: String? = nil, path: String? = nil) {
        self.name = name; self.value = value; self.domain = domain; self.path = path
    }
}

public struct HTTPAuth: Codable {
    public var username: String
    public var password: String
    public init(username: String, password: String) {
        self.username = username; self.password = password
    }
}

public struct Geolocation: Codable {
    public var latitude: Double
    public var longitude: Double
    public var accuracy: Double?
    public init(latitude: Double, longitude: Double, accuracy: Double? = nil) {
        self.latitude = latitude; self.longitude = longitude; self.accuracy = accuracy
    }
}

public struct PDFPageOptions: Codable {
    public var pageSize: String?
    public var landscape: Bool?
    public var marginTop: String?
    public var marginRight: String?
    public var marginBottom: String?
    public var marginLeft: String?
    public init() {}
}

public struct StorageDestination: Codable {
    public var destination: String?
    public var format: String?
    public init(destination: String? = nil, format: String? = nil) {
        self.destination = destination; self.format = format
    }
}

// MARK: - Screenshot

public struct ScreenshotOptions: Codable {
    // Source
    public var url: String?
    public var html: String?
    public var markdown: String?

    // Output
    public var format: String?         // png|jpeg|webp|avif|pdf
    public var quality: Int?

    // Viewport
    public var width: Int?
    public var height: Int?
    public var device: String?

    // Page behaviour
    public var fullPage: Bool?
    public var selector: String?
    public var delay: Int?
    public var timeout: Int?
    public var waitUntil: String?
    public var waitForSelector: String?

    // Visual
    public var darkMode: Bool?

    // Scripting
    public var css: String?
    public var javascript: String?
    public var hideSelectors: [String]?
    public var clickSelector: String?

    // Blocking
    public var blockAds: Bool?
    public var blockTrackers: Bool?
    public var blockCookieBanners: Bool?

    // Identity / auth
    public var userAgent: String?
    public var extraHeaders: [String: String]?
    public var cookies: [Cookie]?
    public var httpAuth: HTTPAuth?

    // Proxy
    public var proxy: String?
    public var premiumProxy: Bool?

    // Environment
    public var geolocation: Geolocation?
    public var timezone: String?

    // PDF options
    public var pdf: PDFPageOptions?

    // Storage
    public var storage: StorageDestination?

    // Webhook
    public var webhookUrl: String?

    public init(url: String? = nil, html: String? = nil, markdown: String? = nil) {
        self.url = url; self.html = html; self.markdown = markdown
    }
}

public struct StorageUploadResult: Decodable {
    public let id: String
    public let url: String
}

// MARK: - Scrape

public struct ScrapeOptions: Codable {
    public var url: String
    public var type: String?          // text|html|links
    public var pages: Int?
    public var waitMs: Int?
    public var proxy: String?
    public var premiumProxy: Bool?
    public var blockResources: Bool?
    public var locale: String?

    public init(url: String) { self.url = url }
}

public struct ScrapeItem: Decodable {
    public let page: Int
    public let url: String
    public let data: String
}

public struct ScrapeResult: Decodable {
    public let success: Bool
    public let results: [ScrapeItem]
}

// MARK: - Extract

public struct ExtractOptions: Codable {
    public var url: String
    public var type: String?          // html|text|markdown|article|links|images|metadata|structured
    public var selector: String?
    public var waitFor: String?
    public var timeout: Int?
    public var darkMode: Bool?
    public var blockAds: Bool?
    public var blockCookieBanners: Bool?
    public var includeImages: Bool?
    public var maxLength: Int?

    public init(url: String) { self.url = url }
}

public struct ExtractResult: Decodable {
    public let success: Bool
    public let type: String
    public let url: String
    public let data: AnyCodable?
    public let responseTime: Int
}

// MARK: - Analyze

public struct AnalyzeOptions: Codable {
    public var url: String
    public var prompt: String?
    public var provider: String?      // openai|anthropic
    public var apiKey: String?
    public var model: String?
    public var jsonSchema: String?
    public var includeScreenshot: Bool?
    public var includeMetadata: Bool?
    public var maxContentLength: Int?

    public init(url: String) { self.url = url }
}

public struct AnalyzeResult: Decodable {
    public let success: Bool
    public let url: String
    public let metadata: [String: AnyCodable]?
    public let analysis: AnyCodable?
    public let provider: String?
    public let model: String?
    public let responseTime: Int
}

// MARK: - Storage

public struct StorageFile: Decodable {
    public let id: String
    public let url: String
    public let size: Int64
    public let format: String?
    public let createdAt: String?
}

public struct StorageFilesResult: Decodable {
    public let success: Bool
    public let files: [StorageFile]
    public let total: Int?
}

public struct StorageUsageResult: Decodable {
    public let success: Bool
    public let used: Int64
    public let limit: Int64?
}

public struct S3Config: Codable {
    public var bucket: String
    public var region: String
    public var accessKeyId: String
    public var secretAccessKey: String
    public var endpoint: String?
    public var publicUrl: String?

    public init(bucket: String, region: String, accessKeyId: String, secretAccessKey: String) {
        self.bucket = bucket; self.region = region
        self.accessKeyId = accessKeyId; self.secretAccessKey = secretAccessKey
    }
}

// MARK: - Scheduled

public struct ScheduledOptions: Codable {
    public var url: String
    public var cronExpression: String
    public var format: String?
    public var width: Int?
    public var height: Int?
    public var fullPage: Bool?
    public var webhookUrl: String?

    public init(url: String, cronExpression: String) {
        self.url = url; self.cronExpression = cronExpression
    }
}

public struct ScheduledJob: Decodable {
    public let id: String
    public let url: String
    public let cronExpression: String
    public let format: String?
    public let active: Bool?
    public let createdAt: String?
    public let nextRunAt: String?
}

public struct ScheduledListResult: Decodable {
    public let success: Bool
    public let jobs: [ScheduledJob]
}

// MARK: - Webhooks

public struct WebhookOptions: Codable {
    public var url: String
    public var events: [String]
    public var secret: String?

    public init(url: String, events: [String]) {
        self.url = url; self.events = events
    }
}

public struct Webhook: Decodable {
    public let id: String
    public let url: String
    public let events: [String]
    public let active: Bool?
    public let createdAt: String?
}

public struct WebhooksListResult: Decodable {
    public let success: Bool
    public let webhooks: [Webhook]
}

// MARK: - API Keys

public struct APIKey: Decodable {
    public let id: String
    public let name: String
    public let key: String?        // only present on creation
    public let createdAt: String?
}

public struct KeysListResult: Decodable {
    public let success: Bool
    public let keys: [APIKey]
}

// MARK: - AnyCodable helper

/// A type-erased Codable value for fields that can be a string, number, bool, array, or object.
public struct AnyCodable: Codable {
    public let value: Any

    public init(_ value: Any) { self.value = value }

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let v = try? c.decode(String.self)  { value = v; return }
        if let v = try? c.decode(Int.self)     { value = v; return }
        if let v = try? c.decode(Double.self)  { value = v; return }
        if let v = try? c.decode(Bool.self)    { value = v; return }
        if let v = try? c.decode([AnyCodable].self) { value = v.map(\.value); return }
        if let v = try? c.decode([String: AnyCodable].self) {
            value = v.mapValues(\.value); return
        }
        value = NSNull()
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch value {
        case let v as String:  try c.encode(v)
        case let v as Int:     try c.encode(v)
        case let v as Double:  try c.encode(v)
        case let v as Bool:    try c.encode(v)
        default:               try c.encodeNil()
        }
    }
}

// MARK: - Video

/// Easing function for scroll animation in video recording.
public enum ScrollEasing: String, Codable, Sendable {
    case linear             = "linear"
    case easeIn             = "ease_in"
    case easeOut            = "ease_out"
    case easeInOut          = "ease_in_out"
    case easeInOutQuint     = "ease_in_out_quint"
}

/// Output format for video recordings.
public enum VideoFormat: String, Codable, Sendable {
    case webm = "webm"
    case mp4  = "mp4"
    case gif  = "gif"
}

/// Options for ``SnapAPI/video(_:)``.
public struct VideoOptions: Encodable, Sendable {
    public var url: String
    public var format: VideoFormat?
    public var width: Int?
    public var height: Int?
    public var duration: Int?
    public var fps: Int?
    public var scrolling: Bool?
    public var scrollSpeed: Int?
    public var scrollDelay: Int?
    public var scrollDuration: Int?
    public var scrollBy: Int?
    public var scrollEasing: ScrollEasing?
    public var scrollBack: Bool?
    public var scrollComplete: Bool?
    public var darkMode: Bool?
    public var blockAds: Bool?
    public var blockCookieBanners: Bool?
    public var delay: Int?
    /// `"binary"` returns raw `Data`; `"base64"` / `"json"` returns ``VideoResult``.
    public var responseType: String?

    public init(url: String) { self.url = url }
}

/// Returned by ``SnapAPI/video(_:)`` when `responseType` is `"base64"` or `"json"`.
public struct VideoResult: Decodable, Sendable {
    public let data: String
    public let mimeType: String
    public let format: VideoFormat
    public let width: Int
    public let height: Int
    public let duration: Int
    public let size: Int
}

// MARK: - Account Usage

/// Returned by ``SnapAPI/usage()``.
public struct AccountUsage: Decodable, Sendable {
    public let used: Int
    public let limit: Int
    public let remaining: Int
    public let resetAt: String?
}

// MARK: - Ping

/// Returned by ``SnapAPI/ping()``.
public struct PingResult: Decodable, Sendable {
    public let status: String
    public let timestamp: Int64
}
