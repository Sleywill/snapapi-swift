import Foundation

// MARK: - AnalyzeProvider

/// LLM provider for the analyze endpoint.
public enum AnalyzeProvider: String, Codable, Sendable, CaseIterable {
    case openai    = "openai"
    case anthropic = "anthropic"
    case google    = "google"
}

// MARK: - AnalyzeOptions

/// Parameters for `POST /v1/analyze`.
///
/// The analyze endpoint extracts content from a URL and sends it to an LLM
/// for analysis. This endpoint may return HTTP 503 when LLM credits are
/// exhausted on the server.
///
/// ```swift
/// var opts = AnalyzeOptions(url: "https://example.com")
/// opts.prompt   = "Summarize this page in 3 bullet points"
/// opts.provider = .openai
/// ```
public struct AnalyzeOptions: Encodable, Sendable {

    /// The URL to analyze. Required.
    public var url: String

    /// Prompt for the LLM.
    public var prompt: String?

    /// LLM provider to use.
    public var provider: AnalyzeProvider?

    /// API key for the LLM provider (your own key, not the SnapAPI key).
    public var apiKey: String?

    /// JSON Schema for structured output.
    public var jsonSchema: [String: AnyCodable]?

    // MARK: Init

    /// Create an analyze options object.
    /// - Parameter url: The URL to analyze.
    public init(url: String) {
        self.url = url
    }
}

// MARK: - AnalyzeResult

/// The response from `POST /v1/analyze`.
public struct AnalyzeResult: Decodable, Sendable {
    /// The LLM analysis result.
    public let result: String
    /// The URL that was analyzed.
    public let url: String
}
