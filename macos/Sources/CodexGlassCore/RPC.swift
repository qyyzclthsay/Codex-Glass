import Foundation
import Darwin

@MainActor
protocol RPCTransport: AnyObject {
    var notification: ((String, JSONValue) -> Void)? { get set }
    func call(_ method: String, params: JSONValue) async throws -> JSONValue
    func stop()
}

enum CodexLocator {
    static func locate(environment: [String: String] = ProcessInfo.processInfo.environment,
                       home: URL = FileManager.default.homeDirectoryForCurrentUser) throws -> URL {
        var candidates: [String] = []
        if let configured = environment["CODEX_GLASS_CODEX_PATH"], !configured.isEmpty { candidates.append(configured) }
        candidates += ["/Applications/Codex.app/Contents/Resources/codex",
                       home.appendingPathComponent("Applications/Codex.app/Contents/Resources/codex").path,
                       "/opt/homebrew/bin/codex", "/usr/local/bin/codex"]
        for directory in (environment["PATH"] ?? "").split(separator: ":", omittingEmptySubsequences: true) {
            if directory.hasPrefix("/") { candidates.append(String(directory) + "/codex") }
        }
        for path in candidates where path.hasPrefix("/") {
            var directory: ObjCBool = false
            if FileManager.default.fileExists(atPath: path, isDirectory: &directory), !directory.boolValue,
               FileManager.default.isExecutableFile(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }
        throw GlassError.codexMissing
    }
}

/// A short-lived, bounded JSON-RPC connection to the official local Codex runtime.
/// No shell command construction, authentication-file reads, or model requests occur here.
@MainActor
final class RPCClient: RPCTransport {
    var notification: ((String, JSONValue) -> Void)?
    private var process: Process?
    private var input: FileHandle?
    private var output: FileHandle?
    private var errorOutput: FileHandle?
    private var generation = UUID()
    private var buffer = Data()
    private var ready = false
    private var nextID = 0
    private var pending: [Int: (CheckedContinuation<JSONValue, Error>, Task<Void, Never>)] = [:]
    private let executable: URL?
    private let arguments: [String]
    private let requestTimeout: TimeInterval
    private let maximumLineBytes = 4 * 1024 * 1024

    init(executable: URL? = nil, arguments: [String] = ["app-server"], requestTimeout: TimeInterval = 25) {
        self.executable = executable; self.arguments = arguments; self.requestTimeout = requestTimeout
    }

    func call(_ method: String, params: JSONValue = .object([:])) async throws -> JSONValue {
        guard ["account/read", "account/rateLimits/read", "account/usage/read", "account/login/start", "account/login/cancel"].contains(method) else {
            throw GlassError.invalidReply
        }
        if !ready { try await start() }
        return try await request(method, params: params)
    }

    private func start() async throws {
        guard process == nil else { throw GlassError.connectionLost }
        let executable = try executable ?? CodexLocator.locate()
        let child = Process()
        child.executableURL = executable; child.arguments = arguments
        let stdin = Pipe(), stdout = Pipe(), stderr = Pipe()
        child.standardInput = stdin; child.standardOutput = stdout; child.standardError = stderr
        // Finder-launched apps often have no package-manager PATH. This also lets a
        // user-installed Codex npm launcher locate its Node runtime without a shell.
        var environment = ProcessInfo.processInfo.environment
        let inherited = environment["PATH"] ?? "/usr/bin:/bin"
        environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:" + inherited
        child.environment = environment
        let token = UUID(); generation = token; process = child
        input = stdin.fileHandleForWriting; output = stdout.fileHandleForReading; errorOutput = stderr.fileHandleForReading
        stdout.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let bytes = handle.availableData
            Task { @MainActor [weak self] in self?.consume(bytes, generation: token) }
        }
        stderr.fileHandleForReading.readabilityHandler = { handle in
            // Drain without storing or logging potential backend/account details.
            if handle.availableData.isEmpty { handle.readabilityHandler = nil }
        }
        child.terminationHandler = { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.generation == token else { return }
                self.close(reason: .connectionLost)
            }
        }
        do { try child.run() }
        catch { close(reason: .startFailed); throw GlassError.startFailed }
        do {
            _ = try await request("initialize", params: .object([
                "clientInfo": .object(["name": .string("codex_glass_macos"), "title": .string("Codex Glass"), "version": .string("0.6.0")])
            ]))
            try write(.object(["method": .string("initialized"), "params": .object([:])]))
            ready = true
        } catch { close(reason: (error as? GlassError) ?? .connectionLost); throw error }
    }

    private func request(_ method: String, params: JSONValue) async throws -> JSONValue {
        try Task.checkCancellation()
        nextID += 1
        let id = nextID
        return try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
                let timeout = Task { @MainActor [weak self] in
                    do { try await Task.sleep(nanoseconds: UInt64(max(0.01, self?.requestTimeout ?? 25) * 1_000_000_000)) }
                    catch { return }
                    guard let self, self.pending[id] != nil else { return }
                    self.close(reason: .timeout)
                }
                pending[id] = (continuation, timeout)
                do { try write(.object(["id": .number(Double(id)), "method": .string(method), "params": params])) }
                catch { close(reason: .connectionLost) }
            }
        }, onCancel: {
            Task { @MainActor [weak self] in
                guard let self, self.pending[id] != nil else { return }
                self.close(reason: .connectionLost)
            }
        })
    }

    private func write(_ value: JSONValue) throws {
        guard let input, process?.isRunning == true else { throw GlassError.connectionLost }
        var data = try JSONEncoder().encode(value)
        guard data.count < maximumLineBytes else { throw GlassError.invalidReply }
        data.append(0x0a)
        try input.write(contentsOf: data)
    }

    private func consume(_ bytes: Data, generation token: UUID) {
        guard token == generation, process != nil else { return }
        guard !bytes.isEmpty else { close(reason: .connectionLost); return }
        buffer.append(bytes)
        while let end = buffer.firstIndex(of: 0x0a) {
            let count = buffer.distance(from: buffer.startIndex, to: end)
            guard count <= maximumLineBytes else { close(reason: .invalidReply); return }
            let line = Data(buffer.prefix(count))
            buffer.removeSubrange(buffer.startIndex...end)
            if line.isEmpty { continue }
            guard let message = try? JSONDecoder().decode(JSONValue.self, from: line), message.object != nil else {
                close(reason: .invalidReply); return
            }
            receive(message)
            if token != generation { return }
        }
        if buffer.count > maximumLineBytes { close(reason: .invalidReply) }
    }

    private func receive(_ message: JSONValue) {
        if message["id"] != .null {
            if message["method"].string != nil {
                try? write(.object(["id": message["id"], "error": .object([
                    "code": .number(-32601), "message": .string("Unsupported client request")
                ])]))
                return
            }
            guard let value = message["id"].number, value >= 0, value < Double(Int.max), value.rounded(.down) == value,
                  let entry = pending.removeValue(forKey: Int(value)) else { return }
            entry.1.cancel()
            if message["error"] != .null {
                let text = (message["error"]["message"].string ?? "").lowercased()
                let error: GlassError
                if text.range(of: "auth|login|sign.in|credential|401|403", options: .regularExpression) != nil { error = .signInRequired }
                else if text.range(of: "429|rate.limit", options: .regularExpression) != nil { error = .rateLimited }
                else { error = .serverError }
                entry.0.resume(throwing: error)
            } else { entry.0.resume(returning: message["result"]) }
        } else if let method = message["method"].string { notification?(method, message["params"]) }
    }

    func stop() { close(reason: .connectionLost, notify: false) }

    private func close(reason: GlassError, notify: Bool = true) {
        let wasRunning = process != nil
        let child = process
        process = nil; ready = false; generation = UUID(); buffer.removeAll(keepingCapacity: false)
        output?.readabilityHandler = nil; errorOutput?.readabilityHandler = nil
        child?.terminationHandler = nil
        try? input?.close(); try? output?.close(); try? errorOutput?.close()
        input = nil; output = nil; errorOutput = nil
        if let child, child.isRunning {
            child.terminate()
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 500_000_000)
                if child.isRunning { Darwin.kill(child.processIdentifier, SIGKILL) }
            }
        }
        let waiting = pending; pending.removeAll()
        for entry in waiting.values { entry.1.cancel(); entry.0.resume(throwing: reason) }
        if wasRunning && notify { notification?("codex-glass/connection-lost", .string(reason.rawValue)) }
    }
}
