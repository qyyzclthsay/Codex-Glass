import XCTest
import Combine
@testable import CodexGlassCore

@MainActor
private final class FixtureTransport: RPCTransport {
    var notification: ((String, JSONValue) -> Void)?
    var replies: [(String, Result<JSONValue, GlassError>)] = []
    var calls: [String] = []
    var stopCount = 0
    var pauseMethod: String?
    var paused: CheckedContinuation<Void, Never>?
    func call(_ method: String, params: JSONValue) async throws -> JSONValue {
        calls.append(method)
        guard !replies.isEmpty else { throw GlassError.invalidReply }
        let next = replies.removeFirst()
        XCTAssertEqual(method, next.0)
        if method == pauseMethod {
            pauseMethod = nil
            await withCheckedContinuation { paused = $0 }
        }
        return try next.1.get()
    }
    func stop() { stopCount += 1; continueReply() }
    func continueReply() { let waiter = paused; paused = nil; waiter?.resume() }
    func enqueue(_ method: String, _ value: JSONValue) { replies.append((method, .success(value))) }
}

final class UsageStoreTests: XCTestCase {
    private func account(_ id: String) -> JSONValue {
        .object(["account": .object(["type": .string("chatgpt"), "id": .string(id), "planType": .string("plus")])])
    }
    private var limits: JSONValue {
        .object(["rateLimits": .object(["primary": .object(["usedPercent": .number(20), "windowDurationMins": .number(300)])])])
    }
    private var daily: JSONValue {
        .object(["dailyUsageBuckets": .array([.object(["startDate": .string("2026-09-01"), "tokens": .number(123)])])])
    }
    private func directory() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }
    @MainActor private func enqueueRefresh(_ rpc: FixtureTransport, id: String = "a") {
        rpc.enqueue("account/read", account(id)); rpc.enqueue("account/rateLimits/read", limits); rpc.enqueue("account/read", account(id))
    }
    @MainActor private func waitForPaused(_ rpc: FixtureTransport) async {
        for _ in 0..<1000 {
            if rpc.paused != nil { return }
            await Task.yield()
        }
        XCTFail("Fixture did not pause")
    }

    @MainActor func testEachRefreshVerifiesAccountBeforeAndAfterAndStopsHelper() async {
        let rpc = FixtureTransport(); enqueueRefresh(rpc)
        let store = UsageStore(dataDirectory: directory(), transport: rpc)
        await store.refresh()
        XCTAssertEqual(store.status, "live")
        XCTAssertEqual(store.snapshot?.windows.first?.remaining, 80)
        XCTAssertEqual(rpc.calls, ["account/read", "account/rateLimits/read", "account/read"])
        XCTAssertEqual(rpc.stopCount, 1)
        store.shutdown()
    }

    @MainActor func testChangedAccountDuringQuotaReadNeverDisplaysResult() async {
        let rpc = FixtureTransport()
        rpc.enqueue("account/read", account("a")); rpc.enqueue("account/rateLimits/read", limits); rpc.enqueue("account/read", account("b"))
        let store = UsageStore(dataDirectory: directory(), transport: rpc)
        await store.refresh()
        XCTAssertNil(store.snapshot)
        XCTAssertEqual(store.error, "accountChanged")
        XCTAssertEqual(store.status, "error")
        XCTAssertEqual(rpc.stopCount, 1)
        store.shutdown()
    }

    @MainActor func testDailyCacheStillVerifiesCurrentAccountAndNeverPersistsHistory() async throws {
        let rpc = FixtureTransport(); enqueueRefresh(rpc)
        let folder = directory()
        let store = UsageStore(dataDirectory: folder, transport: rpc)
        await store.refresh()
        rpc.enqueue("account/read", account("a")); rpc.enqueue("account/usage/read", daily); rpc.enqueue("account/read", account("a"))
        await store.readDaily()
        XCTAssertEqual(store.daily?.days.first?.tokens, 123)
        rpc.enqueue("account/read", account("a"))
        await store.readDaily()
        XCTAssertEqual(rpc.calls.filter { $0 == "account/usage/read" }.count, 1)
        rpc.enqueue("account/read", account("b"))
        await store.readDaily()
        XCTAssertNil(store.daily)
        XCTAssertNil(store.snapshot)
        XCTAssertEqual(store.dailyError, "accountChanged")
        let files = try FileManager.default.contentsOfDirectory(atPath: folder.path)
        XCTAssertEqual(files, ["cache.json"])
        store.shutdown()
    }

    @MainActor func testTransientFailureUsesKnownAccountCacheButColdStartDoesNot() async {
        let rpc = FixtureTransport(); enqueueRefresh(rpc)
        let folder = directory()
        let store = UsageStore(dataDirectory: folder, transport: rpc)
        await store.refresh()
        rpc.replies.append(("account/read", .failure(.timeout)))
        await store.refresh()
        XCTAssertEqual(store.status, "stale")
        XCTAssertNotNil(store.snapshot)
        store.shutdown()
        let second = FixtureTransport(); second.replies.append(("account/read", .failure(.timeout)))
        let cold = UsageStore(dataDirectory: folder, transport: second)
        await cold.refresh()
        XCTAssertNil(cold.snapshot)
        XCTAssertEqual(cold.status, "error")
        cold.shutdown()
    }

    @MainActor func testAPIKeyAccountIsNotMistakenForChatGPTAllowance() async {
        let rpc = FixtureTransport()
        rpc.enqueue("account/read", .object(["account": .object(["type": .string("apiKey"), "id": .string("api")])]))
        let store = UsageStore(dataDirectory: directory(), transport: rpc)
        await store.refresh()
        XCTAssertEqual(store.error, "signInRequired")
        XCTAssertEqual(rpc.calls, ["account/read"])
        store.shutdown()
    }

    @MainActor func testOAuthOnlyStartsExplicitlyAndRejectsUntrustedURL() async {
        let rpc = FixtureTransport()
        let store = UsageStore(dataDirectory: directory(), transport: rpc)
        XCTAssertTrue(rpc.calls.isEmpty)
        rpc.enqueue("account/login/start", .object(["loginId": .string("login"), "authUrl": .string("https://auth.openai.com.attacker.invalid/")]))
        let url = await store.login()
        XCTAssertNil(url)
        XCTAssertFalse(store.loginPending)
        XCTAssertEqual(store.error, "loginFailed")
        XCTAssertGreaterThan(rpc.stopCount, 0)
        store.shutdown()
    }

    @MainActor func testPendingOAuthSuppressesPollingAndCanBeCancelled() async {
        let rpc = FixtureTransport()
        rpc.enqueue("account/login/start", .object(["loginId": .string("login"), "authUrl": .string("https://auth.openai.com/authorize?fixture=1")]))
        let store = UsageStore(dataDirectory: directory(), transport: rpc)
        let url = await store.login()
        XCTAssertNotNil(url)
        XCTAssertTrue(store.loginPending)
        await store.refresh(); await store.readDaily()
        XCTAssertEqual(rpc.calls, ["account/login/start"])
        rpc.notification?("account/login/completed", .object(["loginId": .string("other"), "success": .bool(true)]))
        XCTAssertTrue(store.loginPending)
        rpc.enqueue("account/login/cancel", .object([:]))
        await store.cancelLogin()
        XCTAssertFalse(store.loginPending)
        XCTAssertEqual(rpc.calls.last, "account/login/cancel")
        store.shutdown()
    }

    @MainActor func testLoginURLRejectsCredentialsHTTPAndNonstandardPort() {
        XCTAssertNil(UsageStore.validLoginURL("http://auth.openai.com/authorize"))
        XCTAssertNil(UsageStore.validLoginURL("https://attacker@auth.openai.com/authorize"))
        XCTAssertNil(UsageStore.validLoginURL("https://auth.openai.com:8443/authorize"))
        XCTAssertNotNil(UsageStore.validLoginURL("https://auth.openai.com/authorize?state=fixture"))
    }

    @MainActor func testSleepStopsMonitoringAndWakeCanRefreshAgain() async {
        let rpc = FixtureTransport(); enqueueRefresh(rpc)
        let store = UsageStore(dataDirectory: directory(), transport: rpc)
        await store.refresh()
        store.suspend()
        await store.refresh()
        XCTAssertEqual(rpc.calls.count, 3)
        XCTAssertEqual(store.status, "stale")
        store.resume()
        enqueueRefresh(rpc)
        await store.refresh()
        XCTAssertEqual(rpc.calls.count, 6)
        XCTAssertEqual(store.status, "live")
        store.shutdown()
        store.resume()
        await store.refresh()
        XCTAssertEqual(rpc.calls.count, 6, "Terminal shutdown must not resume")
    }

    @MainActor func testLoginInvalidatesAnAlreadyRunningQuotaRead() async {
        let rpc = FixtureTransport(); enqueueRefresh(rpc)
        rpc.pauseMethod = "account/rateLimits/read"
        let folder = directory()
        let store = UsageStore(dataDirectory: folder, transport: rpc)
        let refresh = Task { @MainActor in await store.refresh() }
        await waitForPaused(rpc)
        rpc.enqueue("account/login/start", .object(["loginId": .string("login"), "authUrl": .string("https://auth.openai.com/authorize")]))
        let login = Task { @MainActor in await store.login() }
        for _ in 0..<1000 { if store.loginPending { break }; await Task.yield() }
        XCTAssertTrue(store.loginPending)
        rpc.continueReply()
        await refresh.value
        _ = await login.value
        XCTAssertNil(store.snapshot, "The previous account must not reappear during login")
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appendingPathComponent("cache.json").path))
        store.shutdown()
    }

    @MainActor func testAccountUpdateInvalidatesInFlightSnapshot() async {
        let rpc = FixtureTransport(); enqueueRefresh(rpc)
        rpc.pauseMethod = "account/rateLimits/read"
        let store = UsageStore(dataDirectory: directory(), transport: rpc)
        let refresh = Task { @MainActor in await store.refresh() }
        await waitForPaused(rpc)
        rpc.notification?("account/updated", .object([:]))
        rpc.continueReply()
        await refresh.value
        XCTAssertNil(store.snapshot)
        XCTAssertNil(store.daily)
        store.shutdown()
    }

    @MainActor func testPublishedSettingsMutationNormalizesWithoutRecursionAndPersists() {
        let rpc = FixtureTransport()
        let folder = directory()
        let store = UsageStore(dataDirectory: folder, transport: rpc)
        var emissions = 0
        let subscription = store.objectWillChange.sink { emissions += 1 }
        store.settings.language = "zh"
        store.settings.compact = false
        store.settings.mainWidth = 1
        XCTAssertEqual(store.settings.language, "zh")
        XCTAssertEqual(store.settings.mainWidth, 320)
        XCTAssertLessThan(emissions, 10, "One mutation must not cause an observer feedback loop")
        let stored = DiskStore(directory: folder).read("settings", as: AppSettings.self)
        XCTAssertEqual(stored?.language, "zh")
        XCTAssertEqual(stored?.mainWidth, 320)
        XCTAssertTrue(rpc.calls.isEmpty)
        subscription.cancel()
        store.shutdown()
    }
}
