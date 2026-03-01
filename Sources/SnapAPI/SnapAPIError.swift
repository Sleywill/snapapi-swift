import Foundation

/// Errors thrown by the SnapAPI SDK.
public enum SnapAPIError: Error, LocalizedError {

    /// A required parameter was missing or invalid.
    case invalidParameters(String)

    /// The API returned a structured error response.
    case apiError(code: String, message: String, statusCode: Int)

    /// The HTTP response could not be decoded.
    case decodingError(underlying: Error)

    /// A network-level error occurred.
    case networkError(underlying: Error)

    /// The server returned an unexpected HTTP status without a parseable body.
    case httpError(statusCode: Int, body: String)

    public var errorDescription: String? {
        switch self {
        case .invalidParameters(let msg):
            return "Invalid parameters: \(msg)"
        case .apiError(let code, let message, let statusCode):
            return "[\(code)] \(message) (HTTP \(statusCode))"
        case .decodingError(let err):
            return "Decoding error: \(err.localizedDescription)"
        case .networkError(let err):
            return "Network error: \(err.localizedDescription)"
        case .httpError(let statusCode, let body):
            return "HTTP \(statusCode): \(body)"
        }
    }

    /// Returns `true` if the request can reasonably be retried.
    public var isRetryable: Bool {
        switch self {
        case .apiError(let code, _, let statusCode):
            return code == "RATE_LIMITED" || code == "TIMEOUT" || statusCode >= 500
        case .networkError:
            return true
        default:
            return false
        }
    }
}

// MARK: - Internal helpers

struct APIErrorResponse: Decodable {
    let statusCode: Int?
    let error: String?
    let message: String?
}

func parseAPIError(data: Data, statusCode: Int) -> SnapAPIError {
    if let decoded = try? JSONDecoder().decode(APIErrorResponse.self, from: data),
       let message = decoded.message {
        let code = decoded.error ?? "HTTP_ERROR"
        return .apiError(code: code, message: message, statusCode: statusCode)
    }
    let body = String(data: data, encoding: .utf8) ?? "<binary>"
    return .httpError(statusCode: statusCode, body: body)
}
