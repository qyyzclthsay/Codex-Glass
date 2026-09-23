import XCTest
@testable import CodexGlassCore

final class RPCTests: XCTestCase {
    private func script(_ body: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("fixture.sh")
        try body.write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    @MainActor func testHandshakeResponseAndNotificationFixture() async throws {
        let file = try script("""
        while IFS= read -r line; do
          case "$line" in
            *'"method":"initialize"'*) printf '%s\\n' '{"id":1,"result":{}}' ;;
            *'"method":"account/read"'*|*'"method":"account\\/read"'*)
              printf '%s\\n' '{"method":"fixture/notice","params":{"ok":true}}'
              printf '%s\\n' '{"id":2,"result":{"account":{"type":"chatgpt","id":"fixture"}}}' ;;
          esac
        done
        """)
        let rpc = RPCClient(executable: URL(fileURLWithPath: "/bin/sh"), arguments: [file.path], requestTimeout: 2)
        defer { rpc.stop() }
        var noticed = false
        rpc.notification = { method, _ in if method == "fixture/notice" { noticed = true } }
        let result = try await rpc.call("account/read")
        XCTAssertEqual(result["account"]["id"].string, "fixture")
        XCTAssertTrue(noticed)
    }

    @MainActor func testEOFCompletesPendingRequestWithoutHanging() async throws {
        let file = try script("""
        while IFS= read -r line; do
          case "$line" in
            *'"method":"initialize"'*) printf '%s\\n' '{"id":1,"result":{}}' ;;
            *'"method":"account/read"'*|*'"method":"account\\/read"'*) exit 0 ;;
          esac
        done
        """)
        let rpc = RPCClient(executable: URL(fileURLWithPath: "/bin/sh"), arguments: [file.path], requestTimeout: 2)
        defer { rpc.stop() }
        do { _ = try await rpc.call("account/read"); XCTFail("Expected EOF failure") }
        catch { XCTAssertEqual(error as? GlassError, .connectionLost) }
    }

    @MainActor func testSilentProcessTimesOutAndDoesNotRemainReady() async throws {
        let file = try script("while IFS= read -r line; do :; done\n")
        let rpc = RPCClient(executable: URL(fileURLWithPath: "/bin/sh"), arguments: [file.path], requestTimeout: 0.1)
        defer { rpc.stop() }
        do { _ = try await rpc.call("account/read"); XCTFail("Expected timeout") }
        catch { XCTAssertEqual(error as? GlassError, .timeout) }
        do { _ = try await rpc.call("account/read"); XCTFail("Expected fresh handshake timeout") }
        catch { XCTAssertEqual(error as? GlassError, .timeout) }
    }

    @MainActor func testOversizedUnterminatedLineIsRejected() async throws {
        let file = try script("/usr/bin/head -c 4194305 /dev/zero | /usr/bin/tr '\\000' x\nwhile IFS= read -r line; do :; done\n")
        let rpc = RPCClient(executable: URL(fileURLWithPath: "/bin/sh"), arguments: [file.path], requestTimeout: 5)
        defer { rpc.stop() }
        do { _ = try await rpc.call("account/read"); XCTFail("Expected bounded-line failure") }
        catch { XCTAssertEqual(error as? GlassError, .invalidReply) }
    }

    @MainActor func testModelRequestsCannotBeSentByTheMonitoringClient() async {
        let rpc = RPCClient()
        do { _ = try await rpc.call("turn/start"); XCTFail("Model request must be rejected") }
        catch { XCTAssertEqual(error as? GlassError, .invalidReply) }
        rpc.stop()
    }

    @MainActor func testStderrIsDrainedAndServerErrorsAreSanitized() async throws {
        let file = try script("""
        while IFS= read -r line; do
          case "$line" in
            *'"method":"initialize"'*)
              /usr/bin/head -c 262144 /dev/zero >&2
              printf '%s\\n' '{"id":1,"result":{}}' ;;
            *'"method":"account/read"'*|*'"method":"account\\/read"'*)
              printf '%s\\n' '{"id":2,"error":{"code":401,"message":"authentication failed for fixture-private-detail"}}' ;;
          esac
        done
        """)
        let rpc = RPCClient(executable: URL(fileURLWithPath: "/bin/sh"), arguments: [file.path], requestTimeout: 2)
        defer { rpc.stop() }
        do { _ = try await rpc.call("account/read"); XCTFail("Expected authentication failure") }
        catch { XCTAssertEqual(error as? GlassError, .signInRequired) }
    }
}
