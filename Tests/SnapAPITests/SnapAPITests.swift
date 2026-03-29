import XCTest
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import SnapAPI

// MARK: - Request Builder Tests

final class RequestBuilderTests: XCTestCase {

    private let builder = RequestBuilder(
        baseURL: URL(string: "https://api.snapapi.pics")!,
        apiKey: "sk_test_builder"
    )

    func testGetRequestMethod() {
        let req = builder.get(path: "/v1/ping")
        XCTAssertEqual(req.httpMethod, "GET")
    }

    func testPostRequestMethod() throws {
        struct Empty: Encodable {}
        let req = try builder.post(path: "/v1/screenshot", body: Empty())
        XCTAssertEqual(req.httpMethod, "POST")
    }

    func testDeleteRequestMethod() {
        let req = builder.delete(path: "/v1/something")
        XCTAssertEqual(req.httpMethod, "DELETE")
    }

    func testBaseURLComposedCorrectly() {
        let req = builder.get(path: "/v1/ping")
        XCTAssertEqual(req.url?.absoluteString, "https://api.snapapi.pics/v1/ping")
    }

    func testApiKeyHeaderSet() {
        let req = builder.get(path: "/v1/ping")
        XCTAssertEqual(req.value(forHTTPHeaderField: "X-Api-Key"), "sk_test_builder")
    }

    func testAuthorizationHeaderSet() {
        let req = builder.get(path: "/v1/ping")
        XCTAssertEqual(req.value(forHTTPHeaderField: "Authorization"), "Bearer sk_test_builder")
    }

    func testContentTypeSetOnPost() throws {
        struct Empty: Encodable {}
        let req = try builder.post(path: "/v1/screenshot", body: Empty())
        XCTAssertEqual(req.value(forHTTPHeaderField: "Content-Type"), "application/json")
    }

    func testTimeoutInterval() {
        let req = builder.get(path: "/v1/ping")
        XCTAssertEqual(req.timeoutInterval, 120)
    }

    func testUserAgentHeader() {
        let req = builder.get(path: "/v1/ping")
        let ua = req.value(forHTTPHeaderField: "User-Agent")
        XCTAssertNotNil(ua)
        XCTAssertTrue(ua!.hasPrefix("snapapi-swift/"))
    }
}

// MARK: - Header Integration Tests

final class HeaderIntegrationTests: XCTestCase {

    func testXApiKeyHeaderIsSent() async throws {
        let body = #"{"used":1,"limit":100,"remaining":99}"#.data(using: .utf8)!
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [HeaderCapturingURLProtocol.self]
        HeaderCapturingURLProtocol.response = MockResponse(statusCode: 200, data: body)
        let session = URLSession(configuration: config)
        let client = SnapAPIClient(
            apiKey: "sk_test_header_check",
            baseURL: URL(string: "https://api.snapapi.pics")!,
            session: session,
            retryPolicy: .never
        )
        _ = try await client.getUsage()
        XCTAssertEqual(HeaderCapturingURLProtocol.capturedAPIKey, "sk_test_header_check")
    }

    func testAuthorizationBearerHeaderIsSent() async throws {
        let body = #"{"used":1,"limit":100,"remaining":99}"#.data(using: .utf8)!
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [HeaderCapturingURLProtocol.self]
        HeaderCapturingURLProtocol.response = MockResponse(statusCode: 200, data: body)
        let session = URLSession(configuration: config)
        let client = SnapAPIClient(
            apiKey: "sk_bearer_test",
            baseURL: URL(string: "https://api.snapapi.pics")!,
            session: session,
            retryPolicy: .never
        )
        _ = try await client.getUsage()
        XCTAssertEqual(HeaderCapturingURLProtocol.capturedAuthHeader, "Bearer sk_bearer_test")
    }
}

// MARK: - Model Tests

final class ModelTests: XCTestCase {

    func testVideoFormatRawValues() {
        XCTAssertEqual(VideoFormat.mp4.rawValue,  "mp4")
        XCTAssertEqual(VideoFormat.webm.rawValue, "webm")
        XCTAssertEqual(VideoFormat.gif.rawValue,  "gif")
    }

    // MARK: AnyCodable

    func testAnyCodableStringRoundTrip() throws {
        let json = #"{"key":"hello"}"#.data(using: .utf8)!
        let d = try JSONDecoder().decode([String: AnyCodable].self, from: json)
        guard case .string(let s) = d["key"]?.value else {
            XCTFail("Expected .string AnyJSON")
            return
        }
        XCTAssertEqual(s, "hello")
    }

    func testAnyCodableIntRoundTrip() throws {
        let json = #"{"n":42}"#.data(using: .utf8)!
        let d = try JSONDecoder().decode([String: AnyCodable].self, from: json)
        guard case .int(let i) = d["n"]?.value else {
            XCTFail("Expected .int AnyJSON")
            return
        }
        XCTAssertEqual(i, 42)
    }

    func testAnyCodableBoolRoundTrip() throws {
        let json = #"{"flag":true}"#.data(using: .utf8)!
        let d = try JSONDecoder().decode([String: AnyCodable].self, from: json)
        guard case .bool(let b) = d["flag"]?.value else {
            XCTFail("Expected .bool AnyJSON")
            return
        }
        XCTAssertTrue(b)
    }

    func testAnyCodableNull() throws {
        let json = #"{"x":null}"#.data(using: .utf8)!
        let d = try JSONDecoder().decode([String: AnyCodable].self, from: json)
        XCTAssertNotNil(d["x"])
        if let val = d["x"] {
            XCTAssertEqual(val.value, .null)
        }
    }

    func testAnyCodableEncodeDecodeRoundTrip() throws {
        let original: AnyCodable = ["name": "Alice", "age": 30, "active": true]
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: encoded)
        XCTAssertEqual(original, decoded)
    }

    func testAnyCodableLiterals() {
        let str: AnyCodable = "hello"
        let num: AnyCodable = 42
        let flag: AnyCodable = true
        let nothing: AnyCodable = nil

        XCTAssertEqual(str.value, .string("hello"))
        XCTAssertEqual(num.value, .int(42))
        XCTAssertEqual(flag.value, .bool(true))
        XCTAssertEqual(nothing.value, .null)
    }

    func testAnyCodableDynamicMemberLookup() throws {
        let json = #"{"user":{"name":"Bob"}}"#.data(using: .utf8)!
        let d = try JSONDecoder().decode(AnyCodable.self, from: json)
        guard case .string(let name) = d.user?.name?.value else {
            XCTFail("Dynamic member lookup failed")
            return
        }
        XCTAssertEqual(name, "Bob")
    }

    func testSnapCookieInit() {
        let c = SnapCookie(name: "session", value: "abc123", domain: ".example.com")
        XCTAssertEqual(c.name,   "session")
        XCTAssertEqual(c.value,  "abc123")
        XCTAssertEqual(c.domain, ".example.com")
        XCTAssertNil(c.path)
    }

    func testGeolocationInit() {
        let g = Geolocation(latitude: 51.5, longitude: -0.1, accuracy: 10)
        XCTAssertEqual(g.latitude,  51.5)
        XCTAssertEqual(g.longitude, -0.1)
        XCTAssertEqual(g.accuracy,  10)
    }

    func testVideoOptionsFullPage() {
        var opts = VideoOptions(url: "https://example.com")
        opts.fullPage = true
        XCTAssertEqual(opts.fullPage, true)
    }

    func testPDFPageOptionsInit() {
        let opts = PDFPageOptions(
            pageSize: .a4,
            landscape: true,
            marginTop: "1cm",
            marginRight: "1cm",
            marginBottom: "1cm",
            marginLeft: "1cm"
        )
        XCTAssertEqual(opts.pageSize, .a4)
        XCTAssertEqual(opts.landscape, true)
        XCTAssertEqual(opts.marginTop, "1cm")
    }
}
