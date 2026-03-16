import Foundation

// MARK: - QuotaResult

/// Returned by `GET /v1/quota`.
public struct QuotaResult: Decodable, Sendable {
    /// Number of API calls used in the current billing period.
    public let used: Int
    /// Total calls allowed in the current billing period.
    public let total: Int
    /// Remaining calls.
    public let remaining: Int
    /// ISO 8601 timestamp when the quota resets.
    public let resetAt: String?
}

// MARK: - PingResult

/// Returned by `GET /v1/ping`.
public struct PingResult: Decodable, Sendable {
    /// Status string, always `"ok"` for healthy responses.
    public let status: String
    /// Unix timestamp in milliseconds.
    public let timestamp: Int64
}

// MARK: - Shared sub-types

/// A browser cookie to inject before navigation.
public struct SnapCookie: Codable, Sendable {
    public var name: String
    public var value: String
    public var domain: String?
    public var path: String?
    public var expires: Double?
    public var httpOnly: Bool?
    public var secure: Bool?
    public var sameSite: String?

    public init(
        name: String,
        value: String,
        domain: String? = nil,
        path: String? = nil
    ) {
        self.name   = name
        self.value  = value
        self.domain = domain
        self.path   = path
    }
}

/// HTTP Basic Auth credentials.
public struct HTTPAuth: Codable, Sendable {
    public var username: String
    public var password: String

    public init(username: String, password: String) {
        self.username = username
        self.password = password
    }
}

/// GPS coordinates for geolocation emulation.
public struct Geolocation: Codable, Sendable {
    public var latitude: Double
    public var longitude: Double
    public var accuracy: Double?

    public init(latitude: Double, longitude: Double, accuracy: Double? = nil) {
        self.latitude  = latitude
        self.longitude = longitude
        self.accuracy  = accuracy
    }
}

/// Storage destination for uploaded screenshots.
public struct StorageDestination: Codable, Sendable {
    public var destination: String?
    public var format: String?

    public init(destination: String? = nil, format: String? = nil) {
        self.destination = destination
        self.format      = format
    }
}
