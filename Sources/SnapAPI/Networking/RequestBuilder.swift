import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Builds authenticated ``URLRequest`` values for the SnapAPI REST API.
struct RequestBuilder {

    let baseURL: URL
    let apiKey: String
    private static let userAgent = "snapapi-swift/3.1.0"

    // MARK: - Builders

    /// Returns a `URLRequest` for a JSON POST with an `Encodable` body.
    func post<B: Encodable>(path: String, body: B) throws -> URLRequest {
        var request = base(method: "POST", path: path)
        request.httpBody = try JSONEncoder.snapAPI.encode(body)
        return request
    }

    /// Returns a `URLRequest` for a GET request.
    func get(path: String) -> URLRequest {
        base(method: "GET", path: path)
    }

    /// Returns a `URLRequest` for a DELETE request.
    func delete(path: String) -> URLRequest {
        base(method: "DELETE", path: path)
    }

    // MARK: - Private

    private func base(method: String, path: String) -> URLRequest {
        // Build the URL manually to avoid double-slash issues with appendingPathComponent
        let urlString = baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            + path
        let url = URL(string: urlString) ?? baseURL
        var req = URLRequest(url: url, timeoutInterval: 120)
        req.httpMethod = method
        req.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        return req
    }
}

// MARK: - Shared JSON encoder

// MARK: - Shared JSON encoder / decoder

extension JSONEncoder {
    /// A shared encoder configured for SnapAPI's snake_case wire format.
    static let snapAPI: JSONEncoder = {
        let enc = JSONEncoder()
        enc.keyEncodingStrategy = .convertToSnakeCase
        return enc
    }()
}

extension JSONDecoder {
    /// A shared decoder configured for SnapAPI's camelCase response bodies.
    static let snapAPI: JSONDecoder = {
        let dec = JSONDecoder()
        dec.keyDecodingStrategy = .convertFromSnakeCase
        return dec
    }()
}
