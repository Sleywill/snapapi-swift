import Foundation

/// Configures how the SDK retries failed requests.
///
/// The default policy retries up to **3 times** with exponential backoff,
/// and always honours the `Retry-After` header on 429 responses.
///
/// ```swift
/// // Custom policy: 5 retries, starting at 2 s backoff
/// let client = SnapAPIClient(
///     apiKey: "sk_...",
///     retryPolicy: RetryPolicy(maxAttempts: 5, baseDelay: 2.0)
/// )
/// ```
public struct RetryPolicy: Sendable {

    /// Maximum number of retry attempts (not counting the initial request).
    public let maxAttempts: Int

    /// Base delay in seconds for the first retry.
    /// Each subsequent delay is doubled (exponential backoff).
    public let baseDelay: TimeInterval

    /// Maximum delay cap in seconds regardless of exponent.
    public let maxDelay: TimeInterval

    /// Creates a retry policy.
    ///
    /// - Parameters:
    ///   - maxAttempts: Number of retries. Use `0` to disable retries.
    ///   - baseDelay:   Initial wait before first retry, in seconds.
    ///   - maxDelay:    Upper cap for any single wait, in seconds.
    public init(
        maxAttempts: Int = 3,
        baseDelay: TimeInterval = 1.0,
        maxDelay: TimeInterval = 30.0
    ) {
        self.maxAttempts = maxAttempts
        self.baseDelay   = baseDelay
        self.maxDelay    = maxDelay
    }

    /// A policy that never retries.
    public static let never = RetryPolicy(maxAttempts: 0)

    /// The default policy used by ``SnapAPIClient`` when none is specified.
    public static let `default` = RetryPolicy()

    // MARK: - Internal

    /// Computes the delay (in nanoseconds) before the attempt at index `attempt`
    /// (0-based, so attempt 0 = first retry).
    ///
    /// If `overrideSeconds` is non-nil (from a Retry-After header) it takes
    /// precedence.
    func delay(forAttempt attempt: Int, overrideSeconds: TimeInterval? = nil) -> UInt64 {
        let seconds: TimeInterval
        if let override = overrideSeconds {
            seconds = min(override, maxDelay)
        } else {
            let exponential = baseDelay * pow(2.0, Double(attempt))
            seconds = min(exponential, maxDelay)
        }
        return UInt64(seconds * 1_000_000_000)
    }

    /// Returns `true` if the error warrants a retry and we have attempts left.
    func shouldRetry(error: SnapAPIError, attempt: Int) -> Bool {
        guard attempt < maxAttempts else { return false }
        return error.isRetryable
    }
}
