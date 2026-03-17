import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Executes HTTP requests with retry logic and structured error mapping.
///
/// This type is an `actor` to ensure all mutable state (retry counters, etc.)
/// is accessed on a single serial executor without data races.
actor HTTPClient {

    private let session: URLSession
    private let retryPolicy: RetryPolicy

    init(session: URLSession = .shared, retryPolicy: RetryPolicy = .default) {
        self.session     = session
        self.retryPolicy = retryPolicy
    }

    // MARK: - Core execute

    /// Performs a request, returning raw `Data` on success.
    ///
    /// Retries automatically for transient errors according to ``RetryPolicy``.
    func data(for request: URLRequest) async throws -> Data {
        var attempt = 0
        while true {
            do {
                return try await performOnce(request: request)
            } catch let error as SnapAPIError {
                guard retryPolicy.shouldRetry(error: error, attempt: attempt) else {
                    throw error
                }
                let ns = retryPolicy.delay(forAttempt: attempt, overrideSeconds: error.retryAfter)
                try await Task.sleep(nanoseconds: ns)
                attempt += 1
            }
        }
    }

    /// Performs a request and decodes the response as `R`.
    func json<R: Decodable>(for request: URLRequest) async throws -> R {
        let raw = try await data(for: request)
        do {
            return try JSONDecoder.snapAPI.decode(R.self, from: raw)
        } catch {
            throw SnapAPIError.decodingError(underlying: error)
        }
    }

    // MARK: - Single attempt

    private func performOnce(request: URLRequest) async throws -> Data {
        let (data, response): (Data, URLResponse)
        do {
            #if canImport(FoundationNetworking)
            // FoundationNetworking on Linux does not expose async data(for:).
            // Bridge the completion-handler API to async/await via a continuation.
            (data, response) = try await withCheckedThrowingContinuation { continuation in
                session.dataTask(with: request) { d, r, e in
                    if let e = e { continuation.resume(throwing: e); return }
                    guard let d = d, let r = r else {
                        continuation.resume(throwing: URLError(.badServerResponse)); return
                    }
                    continuation.resume(returning: (d, r))
                }.resume()
            }
            #else
            (data, response) = try await session.data(for: request)
            #endif
        } catch {
            throw SnapAPIError.networkError(underlying: error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw SnapAPIError.networkError(underlying: URLError(.badServerResponse))
        }

        guard http.statusCode >= 200, http.statusCode < 300 else {
            throw snapAPIError(
                statusCode: http.statusCode,
                data: data,
                headers: http.allHeaderFields
            )
        }

        return data
    }
}
