import Foundation

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
            (data, response) = try await session.data(for: request)
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
