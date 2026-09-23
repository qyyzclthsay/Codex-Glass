import Foundation
import Combine

@MainActor
public final class UsageStore: ObservableObject {
    @Published public var settings: AppSettings {
        didSet {
            settings = settings.validated()
            if !demo { disk.write("settings", settings) }
        }
    }
    @Published public private(set) var snapshot: UsageSnapshot?
    @Published public private(set) var daily: DailyUsage?
    @Published public private(set) var busy = false
    @Published public private(set) var dailyBusy = false
    @Published public private(set) var error: String?
    @Published public private(set) var dailyError: String?
    @Published public private(set) var status = "loading"
    @Published public private(set) var loginPending = false
    public private(set) var failures = 0
    public let demo: Bool
    private let disk: DiskStore
    private let rpc: RPCTransport
    private var identity: String?
    private var fingerprint: String?
    private var generation = 0
    private var lifecycleEpoch = 0
    private var closed = false
    private var suspended = false
    private var locked = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var loginID: String?
    private var loginStarting = false
    private var earlyLoginCompletion: JSONValue?
    private var loginTimeout: Task<Void, Never>?

    public convenience init(demo: Bool = false, dataDirectory: URL? = nil) {
        self.init(demo: demo, dataDirectory: dataDirectory, transport: RPCClient())
    }

    init(demo: Bool = false, dataDirectory: URL? = nil, transport: RPCTransport) {
        self.demo = demo
        let configured = ProcessInfo.processInfo.environment["CODEX_GLASS_DATA_DIR"]
        let environmentDirectory = configured.flatMap { $0.hasPrefix("/") ? URL(fileURLWithPath: $0, isDirectory: true) : nil }
        let directory = dataDirectory ?? environmentDirectory ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Codex Glass", isDirectory: true)
        disk = DiskStore(directory: directory)
        settings = demo ? AppSettings() : (disk.read("settings", as: AppSettings.self) ?? AppSettings())
        rpc = transport
        rpc.notification = { [weak self] method, params in self?.notice(method, params: params) }
    }

    private func acquire() async {
        if !locked { locked = true; return }
        await withCheckedContinuation { waiters.append($0) }
    }
    private func release() {
        if waiters.isEmpty { locked = false } else { waiters.removeFirst().resume() }
    }
    private func forget() {
        identity = nil; fingerprint = nil; snapshot = nil; daily = nil; dailyError = nil; generation += 1
    }
    private func account() async throws -> JSONValue {
        let result = try await rpc.call("account/read", params: .object(["refreshToken": .bool(false)]))
        let account = result["account"]
        guard account["type"].string == "chatgpt", UsageNormalizer.identity(account) != nil else { throw GlassError.signInRequired }
        return account
    }

    public func refresh() async {
        guard !busy, !closed, !suspended, !loginPending else { return }
        let epoch = lifecycleEpoch
        busy = true
        await acquire()
        defer { busy = false; if !loginPending { rpc.stop() }; release() }
        guard !closed, !suspended, !loginPending, epoch == lifecycleEpoch else { return }
        do {
            let result: UsageSnapshot
            if demo { result = UsageNormalizer.demoSnapshot() }
            else {
                let before = try await account()
                guard !closed, !suspended, !loginPending, epoch == lifecycleEpoch else { return }
                let fp = UsageNormalizer.identity(before)
                if fp != fingerprint { forget(); fingerprint = fp }
                let version = generation
                let limits = try await rpc.call("account/rateLimits/read", params: .object([:]))
                let after = try await account()
                guard !closed, !suspended, !loginPending, epoch == lifecycleEpoch, version == generation else { return }
                guard UsageNormalizer.identity(after) == fp else { forget(); throw GlassError.accountChanged }
                result = try UsageNormalizer.snapshot(account: after, result: limits)
                fingerprint = fp
            }
            if identity != result.identity { daily = nil; dailyError = nil; generation += 1 }
            identity = result.identity; snapshot = result; error = nil; status = "live"; failures = 0
            if demo { fingerprint = identity }
            else if identity != nil { disk.write("cache", result) }
        } catch {
            guard !closed, !suspended, !loginPending, epoch == lifecycleEpoch else { return }
            failures += 1
            let code = Self.code(error)
            self.error = code
            if ["signInRequired", "accountChanged", "codexMissing"].contains(code) { forget(); status = "error" }
            else {
                // A failed account read cannot re-identify a persisted cache. Never
                // show an unknown user's saved quota on a cold start.
                snapshot = UsageMath.cached(snapshot ?? disk.read("cache", as: UsageSnapshot.self), identity: identity)
                status = snapshot == nil ? "error" : "stale"
            }
        }
    }

    public func readDaily() async {
        guard !dailyBusy, !closed, !suspended, !loginPending else { return }
        let epoch = lifecycleEpoch
        dailyBusy = true; dailyError = nil
        await acquire()
        defer { dailyBusy = false; if !loginPending { rpc.stop() }; release() }
        guard !closed, !suspended, !loginPending, epoch == lifecycleEpoch else { return }
        let accountID = identity, fp = fingerprint, version = generation
        do {
            guard accountID != nil else { throw GlassError.signInRequired }
            if demo { daily = UsageNormalizer.demoDaily(); return }
            let before = try await account()
            guard !closed, !suspended, !loginPending, epoch == lifecycleEpoch else { return }
            guard UsageNormalizer.identity(before) == fp, version == generation else { throw GlassError.accountChanged }
            if let daily {
                let age = Date().timeIntervalSince(daily.observedAt)
                if age >= 0 && age < 60 { return }
            }
            let result = try await rpc.call("account/usage/read", params: .object([:]))
            let after = try await account()
            guard !closed, !suspended, !loginPending, epoch == lifecycleEpoch else { return }
            guard UsageNormalizer.identity(after) == fp, identity == accountID, version == generation else {
                throw GlassError.accountChanged
            }
            daily = try UsageNormalizer.daily(result)
        } catch {
            guard !closed, !suspended, !loginPending, epoch == lifecycleEpoch else { return }
            let code = Self.code(error)
            daily = nil; dailyError = code
            if ["accountChanged", "signInRequired"].contains(code) {
                forget(); status = "error"; self.error = code; dailyError = code
            }
        }
    }

    /// Initiates OAuth only from an explicit user action. The UI opens the returned
    /// official URL; successful completion arrives through app-server notification.
    public func login() async -> URL? {
        guard !closed, !suspended, !loginPending, !demo else { return nil }
        let epoch = lifecycleEpoch
        forget()
        loginPending = true; loginStarting = true; error = nil
        await acquire()
        defer { loginStarting = false; release() }
        guard !closed, !suspended, epoch == lifecycleEpoch else { loginPending = false; return nil }
        do {
            let reply = try await rpc.call("account/login/start", params: .object(["type": .string("chatgpt")]))
            guard !closed, !suspended, epoch == lifecycleEpoch else { return nil }
            guard let string = reply["authUrl"].string, let url = Self.validLoginURL(string),
                  let id = reply["loginId"].string, !id.isEmpty else { throw GlassError.loginFailed }
            loginID = id
            loginTimeout?.cancel()
            loginTimeout = Task { @MainActor [weak self] in
                do { try await Task.sleep(nanoseconds: 300_000_000_000) } catch { return }
                guard let self, self.loginPending, self.loginID == id else { return }
                await self.cancelLogin()
                self.error = "loginFailed"
            }
            if let completion = earlyLoginCompletion {
                earlyLoginCompletion = nil
                Task { @MainActor [weak self] in self?.notice("account/login/completed", params: completion) }
            }
            return url
        } catch {
            guard !closed, !suspended, epoch == lifecycleEpoch else { return nil }
            loginID = nil; loginPending = false; earlyLoginCompletion = nil
            self.error = "loginFailed"; rpc.stop(); return nil
        }
    }

    public func cancelLogin() async {
        loginTimeout?.cancel(); loginTimeout = nil
        await acquire()
        defer { release() }
        let id = loginID
        loginID = nil; loginPending = false; earlyLoginCompletion = nil
        if !closed, let id { _ = try? await rpc.call("account/login/cancel", params: .object(["loginId": .string(id)])) }
        rpc.stop()
    }

    public func shutdown() {
        closed = true
        suspend()
    }

    /// Sleep stops the helper without permanently closing the observable store.
    public func suspend() {
        suspended = true; lifecycleEpoch += 1
        loginTimeout?.cancel(); loginTimeout = nil
        loginPending = false; loginID = nil
        earlyLoginCompletion = nil
        rpc.stop()
        if snapshot != nil { status = "stale" }
    }

    public func resume() {
        if !closed { suspended = false }
    }

    private func notice(_ method: String, params: JSONValue) {
        guard !closed else { return }
        if method == "account/login/completed" {
            if loginStarting && loginID == nil { earlyLoginCompletion = params; return }
            guard let id = loginID, params["loginId"].string == id else { return }
            loginTimeout?.cancel(); loginTimeout = nil; loginID = nil; loginPending = false
            if params["success"].bool == false { error = "loginFailed"; rpc.stop(); return }
            forget()
            Task { @MainActor [weak self] in await self?.refresh() }
        } else if method == "codex-glass/connection-lost", loginPending {
            loginTimeout?.cancel(); loginTimeout = nil; loginID = nil; loginPending = false
            error = "loginFailed"
        } else if method == "account/updated", !loginPending {
            // Invalidate first; the next verified read will display the new account.
            forget()
        }
    }

    static func validLoginURL(_ string: String) -> URL? {
        guard let components = URLComponents(string: string), components.scheme == "https",
              let host = components.host?.lowercased(), ["auth.openai.com", "auth0.openai.com", "chatgpt.com"].contains(host),
              components.user == nil, components.password == nil,
              components.port == nil || components.port == 443 else { return nil }
        return components.url
    }
    private static func code(_ error: Error) -> String { (error as? GlassError)?.rawValue ?? "serverError" }
}
