import Foundation

/// All errors thrown by the SnapAPI Swift SDK.
///
/// Use a `switch` or `catch` pattern to handle specific failure modes:
///
/// ```swift
/// do {
///     let data = try await client.screenshot(ScreenshotOptions(url: "https://example.com"))
/// } catch SnapAPIError.authenticationFailed {
///     print("Invalid API key")
/// } catch SnapAPIError.rateLimited(let retryAfter) {
///     try await Task.sleep(for: .seconds(retryAfter))
/// } catch SnapAPIError.quotaExceeded {
///     print("Upgrade your plan at snapapi.pics/dashboard")
/// } catch SnapAPIError.serverError(let code, let message) {
///     print("Server error \(code): \(message)")
/// } catch SnapAPIError.networkError(let underlying) {
///     print("Network problem: \(underlying)")
/// } catch SnapAPIError.decodingError(let underlying) {
///     print("Decoding failed: \(underlying)")
/// }
/// ```
public enum SnapAPIError: Error, LocalizedError, Sendable {

    // MARK: - Cases

    /// The API key is missing, invalid, or has been revoked (HTTP 401/403).
    case authenticationFailed

    /// The rate limit was exceeded (HTTP 429).
    ///
    /// Wait at least `retryAfter` seconds before retrying. The SDK's built-in
    /// retry policy honours this value automatically.
    case rateLimited(retryAfter: TimeInterval)

    /// The account's request quota for the current billing period is exhausted (HTTP 402).
    case quotaExceeded

    /// The API returned a non-2xx response.
    ///
    /// - Parameters:
    ///   - statusCode: The HTTP status code.
    ///   - message:    Human-readable description returned by the server.
    case serverError(statusCode: Int, message: String)

    /// A network-level failure (DNS, TLS, timeout, etc.).
    case networkError(underlying: Error)

    /// A required parameter was missing or had an invalid value.
    case invalidParameters(String)

    /// The server response could not be decoded into the expected type.
    case decodingError(underlying: Error)

    // MARK: - LocalizedError

    public var errorDescription: String? {
        switch self {
        case .authenticationFailed:
            return "Authentication failed: invalid or missing API key."
        case .rateLimited(let retryAfter):
            return "Rate limited. Retry after \(Int(retryAfter)) second(s)."
        case .quotaExceeded:
            return "Quota exceeded. Upgrade your plan at snapapi.pics/dashboard."
        case .serverError(let code, let message):
            return "Server error (HTTP \(code)): \(message)"
        case .networkError(let err):
            return "Network error: \(err.localizedDescription)"
        case .invalidParameters(let msg):
            return "Invalid parameters: \(msg)"
        case .decodingError(let err):
            return "Decoding error: \(err.localizedDescription)"
        }
    }

    // MARK: - Retry helpers

    /// Whether this error is transient and the request can be safely retried.
    public var isRetryable: Bool {
        switch self {
        case .rateLimited, .networkError:
            return true
        case .serverError(let code, _):
            return code >= 500
        default:
            return false
        }
    }

    /// The number of seconds to wait before the next retry attempt, if known.
    public var retryAfter: TimeInterval? {
        guard case .rateLimited(let t) = self else { return nil }
        return t
    }
}

// MARK: - Internal parsing

/// Wire representation of a SnapAPI error body.
struct APIErrorBody: Decodable {
    let statusCode: Int?
    let error: String?
    let message: String?
}

/// Parse the HTTP response into the appropriate ``SnapAPIError`` case.
func snapAPIError(statusCode: Int, data: Data, headers: [AnyHashable: Any]) -> SnapAPIError {
    switch statusCode {
    case 401, 403:
        return .authenticationFailed
    case 429:
        let retryAfter = retryAfterValue(from: headers)
        return .rateLimited(retryAfter: retryAfter)
    case 402:
        return .quotaExceeded
    default:
        let body = (try? JSONDecoder().decode(APIErrorBody.self, from: data))
        let message = body?.message
            ?? String(data: data, encoding: .utf8)
            ?? "HTTP \(statusCode)"
        return .serverError(statusCode: statusCode, message: message)
    }
}

private func retryAfterValue(from headers: [AnyHashable: Any]) -> TimeInterval {
    // The Retry-After header may carry an integer number of seconds.
    if let raw = headers["Retry-After"] as? String ?? headers["retry-after"] as? String,
       let seconds = TimeInterval(raw) {
        return seconds
    }
    return 60 // safe fallback
}
