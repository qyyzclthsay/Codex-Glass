import XCTest
@testable import CodexGlassCore

final class UsageMathTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private func json(_ text: String) throws -> JSONValue { try JSONDecoder().decode(JSONValue.self, from: Data(text.utf8)) }

    func testMissingValuesDoNotBecomeZeroQuota() throws {
        let raw = try json(#"{"rateLimitsByLimitId":{"codex":{"primary":{"usedPercent":null},"secondary":{"usedPercent":0,"windowDurationMins":10080}},"extra":{"primary":{"usedPercent":150}}}}"#)
        let snapshot = try UsageNormalizer.snapshot(account: .object([:]), result: raw, now: now)
        XCTAssertEqual(snapshot.windows.count, 2)
        XCTAssertEqual(snapshot.windows[0].remaining, 100)
        XCTAssertEqual(snapshot.windows[1].remaining, 0)
        XCTAssertNil(snapshot.resets.count)
    }

    func testLegacyLimitsAndResetExpiry() throws {
        let raw = try json(#"{"rateLimits":{"primary":{"usedPercent":31,"windowDurationMins":300}},"rateLimitResetCredits":{"availableCount":2,"credits":[{"status":"available","expiresAt":1800000500},{"status":"available","expiresAt":1700000000},{"status":"used","expiresAt":1800000100}]}}"#)
        let snapshot = try UsageNormalizer.snapshot(account: .object(["email": .string("fixture@example.invalid")]), result: raw, now: now)
        XCTAssertEqual(snapshot.windows.first?.group, "codex")
        XCTAssertEqual(snapshot.windows.first?.remaining, 69)
        XCTAssertEqual(snapshot.resets.count, 2)
        XCTAssertEqual(snapshot.resets.expiresAt, now.addingTimeInterval(500))
        XCTAssertEqual(snapshot.identity?.count, 64)
        XCTAssertFalse(snapshot.identity?.contains("fixture") ?? true)
    }

    func testSelectedWindowUsesMainPoolAndFallsBackForMissingPreference() {
        let expired = QuotaWindow(id: "expired", minutes: 300, remaining: 1, resetsAt: now.addingTimeInterval(-1))
        let week = QuotaWindow(id: "week", minutes: 10080, remaining: 72, resetsAt: now.addingTimeInterval(300))
        let other = QuotaWindow(id: "other", group: "reserve", remaining: 0)
        let snapshot = UsageSnapshot(windows: [expired, week, other])
        XCTAssertEqual(UsageMath.selected(snapshot: snapshot, choice: "five", now: now)?.id, "week")
        XCTAssertNil(UsageMath.selected(snapshot: UsageSnapshot(windows: [other]), choice: "auto", now: now))
    }

    func testElapsedArcIsElapsedTimeRatherThanRemainingQuota() {
        let window = QuotaWindow(id: "five", minutes: 300, remaining: 88, resetsAt: now.addingTimeInterval(9000))
        XCTAssertEqual(UsageMath.elapsed(window: window, now: now), 0.5)
        XCTAssertEqual(UsageMath.elapsed(window: window, now: now.addingTimeInterval(20000)), 1)
        XCTAssertNil(UsageMath.elapsed(window: QuotaWindow(id: "unknown", remaining: 50), now: now))
    }

    func testDailyConflictingDuplicatesAreMissingAndActualZeroSurvives() throws {
        let raw = try json(#"{"dailyUsageBuckets":[{"startDate":"2026-09-01","tokens":0},{"startDate":"2026-09-02","tokens":100},{"startDate":"2026-09-02","tokens":200},{"startDate":"2026-09-03","tokens":42},{"startDate":"2026-09-03","tokens":42},{"startDate":"2026-02-30","tokens":123},{"startDate":"2026-09-04","tokens":-1},{"startDate":"2026-09-05","tokens":true}]}"#)
        let usage = try UsageNormalizer.daily(raw, now: now)
        XCTAssertTrue(usage.incomplete)
        XCTAssertEqual(usage.days, [DailyRecord(date: "2026-09-01", tokens: 0), DailyRecord(date: "2026-09-03", tokens: 42)])
        let formatter = DateFormatter(); formatter.dateFormat = "yyyy-MM-dd"; formatter.locale = Locale(identifier: "en_US_POSIX")
        let series = UsageMath.series(usage: usage, range: 3, today: try XCTUnwrap(formatter.date(from: "2026-09-03")))
        XCTAssertEqual(series.count, 3)
        XCTAssertEqual(series[0].tokens, 0)
        XCTAssertNil(series[1].tokens)
        XCTAssertEqual(series[2].tokens, 42)
    }

    func testMissingDailyArrayDoesNotPretendUsageIsEmpty() throws {
        XCTAssertThrowsError(try UsageNormalizer.daily(json(#"{"dailyUsageBuckets":null}"#)))
        XCTAssertEqual(try UsageNormalizer.daily(json(#"{"dailyUsageBuckets":[]}"#)).days, [])
    }

    func testChineseUnitsAndTinyPositiveCounts() {
        XCTAssertEqual(UsageMath.tokens(31_884_595, language: "zh"), "3188.46 万")
        XCTAssertEqual(UsageMath.tokens(133_268_538, language: "zh", total: true), "1.33 亿")
        XCTAssertEqual(UsageMath.tokens(78_743_291, language: "zh-TW", total: true), "0.79 億")
        XCTAssertEqual(UsageMath.tokens(1, language: "zh"), "<0.01 万")
        XCTAssertEqual(UsageMath.tokens(0, language: "zh"), "0 万")
        XCTAssertEqual(UsageMath.tokens(nil, language: "zh"), "—")
        XCTAssertEqual(UsageMath.tokens(.infinity, language: "en"), "—")
        XCTAssertEqual(UsageMath.tokens(31_884_595, language: "en"), "31.88 M")
    }

    func testCacheNeedsMatchingVerifiedIdentityAndFreshWindows() {
        let snapshot = UsageSnapshot(identity: "account-a", windows: [
            QuotaWindow(id: "old", remaining: 20, resetsAt: now.addingTimeInterval(-1)),
            QuotaWindow(id: "live", remaining: 60, resetsAt: now.addingTimeInterval(100))
        ], resets: ResetCredits(count: 2), observedAt: now.addingTimeInterval(-60))
        XCTAssertNil(UsageMath.cached(snapshot, identity: nil, now: now))
        XCTAssertNil(UsageMath.cached(snapshot, identity: "account-b", now: now))
        let cached = UsageMath.cached(snapshot, identity: "account-a", now: now)
        XCTAssertEqual(cached?.windows.map(\.id), ["live"])
        XCTAssertNil(cached?.resets.count)
        XCTAssertNil(UsageMath.cached(snapshot, identity: "account-a", now: now.addingTimeInterval(90000)))
        XCTAssertNil(UsageMath.cached(snapshot, identity: "account-a", now: now.addingTimeInterval(-120)))
    }

    func testSettingsRecoverMissingFieldsAndRejectUnsafeValues() throws {
        let raw = Data(#"{"language":"xx","refreshSeconds":1,"accentColor":"red","mainWidth":1,"membership":{"raw@example.invalid":{"date":"2026-09-01","kind":"renewal"}}}"#.utf8)
        let settings = try JSONDecoder().decode(AppSettings.self, from: raw)
        XCTAssertEqual(settings.language, AppSettings.defaultLanguage)
        XCTAssertEqual(settings.refreshSeconds, 120)
        XCTAssertNil(settings.accentColor)
        XCTAssertEqual(settings.mainWidth, 320)
        XCTAssertTrue(settings.membership.isEmpty)
        XCTAssertTrue(settings.pinned)
        XCTAssertEqual(settings.theme, "system")
    }

    func testSettingsPersistNoRawAccountIdentifiers() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let disk = DiskStore(directory: directory)
        let account = JSONValue.object(["email": .string("private-fixture@example.invalid")])
        let hash = try XCTUnwrap(UsageNormalizer.identity(account))
        var settings = AppSettings()
        settings.membership[hash] = MembershipDate(date: "2026-09-01")
        disk.write("settings", settings)
        let data = try String(contentsOf: directory.appendingPathComponent("settings.json"), encoding: .utf8)
        XCTAssertFalse(data.contains("private-fixture"))
        XCTAssertTrue(data.contains(hash))
        XCTAssertEqual(disk.read("settings", as: AppSettings.self)?.membership[hash]?.date, "2026-09-01")
    }
}
