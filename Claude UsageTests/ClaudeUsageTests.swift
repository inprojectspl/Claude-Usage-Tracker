import XCTest
@testable import Claude_Usage

final class ClaudeUsageTests: XCTestCase {

    // MARK: - Status Level Tests (Deprecated Property - uses remaining-based thresholds)

    func testStatusLevelSafe() {
        // statusLevel uses remaining-based thresholds: safe when remaining >= 20%
        let usage = createUsage(sessionPercentage: 0)  // 100% remaining
        XCTAssertEqual(usage.statusLevel, .safe)

        let usage25 = createUsage(sessionPercentage: 25)  // 75% remaining
        XCTAssertEqual(usage.statusLevel, .safe)

        let usage80 = createUsage(sessionPercentage: 80)  // 20% remaining (exact boundary)
        XCTAssertEqual(usage.statusLevel, .safe)
    }

    func testStatusLevelModerate() {
        // statusLevel uses remaining-based thresholds: moderate when 10% <= remaining < 20%
        let usage81 = createUsage(sessionPercentage: 81)  // 19% remaining
        XCTAssertEqual(usage81.statusLevel, .moderate)

        let usage85 = createUsage(sessionPercentage: 85)  // 15% remaining
        XCTAssertEqual(usage85.statusLevel, .moderate)

        let usage90 = createUsage(sessionPercentage: 90)  // 10% remaining (exact boundary)
        XCTAssertEqual(usage90.statusLevel, .moderate)
    }

    func testStatusLevelCritical() {
        // statusLevel uses remaining-based thresholds: critical when remaining < 10%
        let usage91 = createUsage(sessionPercentage: 91)  // 9% remaining
        XCTAssertEqual(usage91.statusLevel, .critical)

        let usage95 = createUsage(sessionPercentage: 95)  // 5% remaining
        XCTAssertEqual(usage95.statusLevel, .critical)

        let usage100 = createUsage(sessionPercentage: 100)  // 0% remaining
        XCTAssertEqual(usage100.statusLevel, .critical)
    }

    // MARK: - Empty Usage Tests

    func testEmptyUsage() {
        let empty = ClaudeUsage.empty

        XCTAssertEqual(empty.sessionTokensUsed, 0)
        XCTAssertEqual(empty.sessionPercentage, 0)
        XCTAssertEqual(empty.weeklyTokensUsed, 0)
        XCTAssertEqual(empty.weeklyPercentage, 0)
        XCTAssertEqual(empty.statusLevel, .safe)
        XCTAssertNil(empty.costUsed)
        XCTAssertNil(empty.costLimit)
    }

    // MARK: - Codable Tests

    func testEncodeDecode() throws {
        let original = createUsage(sessionPercentage: 45.5)

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ClaudeUsage.self, from: data)

        XCTAssertEqual(original, decoded)
    }

    func testDeepSeekUsageDecode() throws {
        let json = """
        {
            "user": "test-user",
            "role": "power",
            "status": "active",
            "daily": {
                "budget_usd": 5.0,
                "spent_usd": 1.25,
                "remaining_usd": 3.75,
                "requests": 4
            },
            "monthly": {
                "budget_usd": 20.0,
                "spent_usd": 2.5,
                "remaining_usd": 17.5,
                "requests": 12
            },
            "last_request_at": "2026-06-15T10:42:52Z",
            "window_basis": "daily budget resets at UTC midnight"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let usage = try decoder.decode(DeepSeekUsage.self, from: json)

        XCTAssertEqual(usage.user, "test-user")
        XCTAssertEqual(usage.status, "active")
        XCTAssertEqual(usage.daily.budgetUSD, 5.0)
        XCTAssertEqual(usage.daily.spentUSD, 1.25)
        XCTAssertEqual(usage.daily.remainingUSD, 3.75)
        XCTAssertEqual(usage.daily.requests, 4)
        XCTAssertEqual(usage.monthly.usagePercentage, 12.5)
        XCTAssertTrue(usage.isActive)
        XCTAssertNotNil(usage.lastRequestAt)
    }

    func testDeepSeekRejectsPlainHTTPEndpoint() async {
        do {
            _ = try await ClaudeAPIService().fetchDeepSeekUsage(
                endpoint: "http://example.com/me/api",
                apiToken: "test-token"
            )
            XCTFail("Expected plain HTTP DeepSeek endpoints to be rejected")
        } catch {
            XCTAssertNotNil(error)
        }
    }

    // MARK: - Helpers

    private func createUsage(sessionPercentage: Double) -> ClaudeUsage {
        ClaudeUsage(
            sessionTokensUsed: Int(sessionPercentage * 1000),
            sessionLimit: 100000,
            sessionPercentage: sessionPercentage,
            sessionResetTime: Date().addingTimeInterval(3600),
            weeklyTokensUsed: 500000,
            weeklyLimit: 1000000,
            weeklyPercentage: 50,
            weeklyResetTime: Date().addingTimeInterval(86400),
            opusWeeklyTokensUsed: 0,
            opusWeeklyPercentage: 0,
            sonnetWeeklyTokensUsed: 0,
            sonnetWeeklyPercentage: 0,
            sonnetWeeklyResetTime: nil,
            costUsed: nil,
            costLimit: nil,
            costCurrency: nil,
            lastUpdated: Date(),
            userTimezone: .current
        )
    }
}
