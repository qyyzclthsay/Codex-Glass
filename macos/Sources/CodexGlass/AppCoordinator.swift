import AppKit
import SwiftUI
import Combine
import ServiceManagement
import UserNotifications
import CodexGlassCore

@main
enum CodexGlassApplication {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = AppCoordinator()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { app.run() }
    }
}

@MainActor
final class AppCoordinator: NSObject, ObservableObject, NSApplicationDelegate, NSWindowDelegate, UNUserNotificationCenterDelegate {
    let store: UsageStore
    let demo: Bool
    let smoke: Bool
    @Published var showingSettings = false
    @Published var dailyOpen = false
    @Published var otherOpen = false
    // Deterministic view state for screenshot QA; never used in normal operation.
    @Published var smokeChartRange = 7
    @Published var smokeChartDay: Int?
    @Published var now = Date()
    @Published var platformError: String?
    private(set) var mainWindow: NSWindow!
    private(set) var miniWindow: NSPanel!
    private(set) var compactView: CompactView!
    private var statusItem: NSStatusItem!
    private var subscriptions = Set<AnyCancellable>()
    private var pollTimer: Timer?
    private var clockTimer: Timer?
    private var pollTask: Task<Void, Never>?
    private var sleeping = false
    private var failures = 0
    private var lastRefresh = Date.distantPast
    private var lastSettings: AppSettings?
    private var closing = false
    private var notificationKeys = Set<String>()
    private let smokeDirectory: URL?

    override init() {
        let args = ProcessInfo.processInfo.arguments
        smoke = args.contains("--smoke-test")
        demo = smoke || args.contains("--demo")
        smokeDirectory = ProcessInfo.processInfo.environment["CODEX_GLASS_QA_DIR"].map { URL(fileURLWithPath: $0, isDirectory: true) }
        store = UsageStore(demo: demo, dataDirectory: smoke ? smokeDirectory?.appendingPathComponent("profile") : nil)
        super.init()
    }

    var language: String { store.settings.language }
    func t(_ key: String) -> String { Copy.text(key, language) }
    var selected: QuotaWindow? { UsageMath.selected(snapshot: store.snapshot, choice: store.settings.ringWindow, now: now) }

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildWindows()
        buildApplicationMenu()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "circle.dashed.inset.filled", accessibilityDescription: "Codex Glass")
        statusItem.button?.image?.isTemplate = true
        statusItem.button?.target = self
        statusItem.button?.action = #selector(statusClick(_:))
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        store.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { self?.storeChanged() }
        }.store(in: &subscriptions)
        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(self, selector: #selector(willSleep), name: NSWorkspace.willSleepNotification, object: nil)
        workspace.addObserver(self, selector: #selector(didWake), name: NSWorkspace.didWakeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(screenChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        if !demo && Bundle.main.bundleIdentifier != nil {
            UNUserNotificationCenter.current().delegate = self
            // Reconcile an externally disabled login item without prompting at launch.
            store.settings.startup = SMAppService.mainApp.status == .enabled
        }
        applySettings()
        if !ProcessInfo.processInfo.arguments.contains("--background") {
            if store.settings.compact { showCompact() } else { showMain() }
        }
        clockTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.clockTick() }
        }
        clockTimer?.tolerance = 2
        refresh()
        if smoke { Task { await runSmokeTest() } }
    }

    private func buildWindows() {
        let initial = NSRect(x: 0, y: 0, width: store.settings.mainWidth, height: store.settings.mainHeight)
        mainWindow = NSWindow(contentRect: initial, styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
        mainWindow.title = "Codex Glass"
        mainWindow.titleVisibility = .hidden
        mainWindow.titlebarAppearsTransparent = true
        mainWindow.isMovableByWindowBackground = true
        mainWindow.isReleasedWhenClosed = false
        mainWindow.contentMinSize = NSSize(width: 320, height: 360)
        mainWindow.contentMaxSize = NSSize(width: 900, height: 1400)
        mainWindow.delegate = self
        let mainFrameName = demo ? "CodexGlassDemoMain" : "CodexGlassMain"
        mainWindow.setFrameAutosaveName(mainFrameName)
        mainWindow.contentView = NSHostingView(rootView: MainView(controller: self, store: store))
        if smoke || !mainWindow.setFrameUsingName(mainFrameName) { mainWindow.center() }
        miniWindow = MiniPanel(contentRect: NSRect(x: 0, y: 0, width: 92, height: 126), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        miniWindow.isOpaque = false
        miniWindow.backgroundColor = .clear
        miniWindow.hasShadow = false
        miniWindow.isReleasedWhenClosed = false
        miniWindow.hidesOnDeactivate = false
        miniWindow.isMovableByWindowBackground = false
        miniWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let miniFrameName = demo ? "CodexGlassDemoMini" : "CodexGlassMini"
        miniWindow.setFrameAutosaveName(miniFrameName)
        compactView = CompactView(controller: self)
        miniWindow.contentView = compactView
        if (smoke || !miniWindow.setFrameUsingName(miniFrameName)), let screen = NSScreen.main?.visibleFrame {
            miniWindow.setFrameOrigin(NSPoint(x: screen.maxX - 130, y: screen.maxY - 180))
        }
    }

    private func buildApplicationMenu() {
        let menu = NSMenu()
        let appMenu = NSMenu()
        let root = NSMenuItem()
        root.submenu = appMenu
        menu.addItem(root)
        appMenu.addItem(withTitle: "Codex Glass", action: #selector(openMain), keyEquivalent: "1").target = self
        appMenu.addItem(withTitle: t("settings"), action: #selector(openSettings), keyEquivalent: ",").target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: t("quit"), action: #selector(quit), keyEquivalent: "q").target = self
        let editMenu = NSMenu(title: "Edit")
        for (title, action, key) in [("Cut", #selector(NSText.cut(_:)), "x"), ("Copy", #selector(NSText.copy(_:)), "c"), ("Paste", #selector(NSText.paste(_:)), "v"), ("Select All", #selector(NSText.selectAll(_:)), "a")] {
            editMenu.addItem(withTitle: title, action: action, keyEquivalent: key)
        }
        let edit = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        edit.submenu = editMenu
        menu.addItem(edit)
        NSApp.mainMenu = menu
    }

    func menu() -> NSMenu {
        let menu = NSMenu()
        for (title, action) in [(t("expand"), #selector(openMain)), (t("compact"), #selector(openCompact)), (t("settings"), #selector(openSettings)), (t("refresh"), #selector(refreshFromMenu)), (t("usage"), #selector(openUsage)), (t("restoreSize"), #selector(restoreSize))] {
            menu.addItem(withTitle: title, action: action, keyEquivalent: "").target = self
        }
        menu.addItem(.separator())
        menu.addItem(withTitle: t("quit"), action: #selector(quit), keyEquivalent: "q").target = self
        return menu
    }

    @objc private func statusClick(_ sender: Any?) {
        guard let button = statusItem.button else { return }
        if NSApp.currentEvent?.type == .rightMouseUp {
            menu().popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
        } else if store.settings.compact { showCompact() } else { showMain() }
    }

    @objc func openMain() { showMain() }
    @objc func openCompact() { showCompact() }
    @objc func openSettings() { showingSettings = true; showMain(preserveSettings: true) }
    @objc func openUsage() { NSWorkspace.shared.open(URL(string: "https://chatgpt.com/codex/settings/usage")!) }
    @objc func refreshFromMenu() { refresh() }
    @objc func restoreSize() {
        mainWindow.setContentSize(NSSize(width: 360, height: 550))
        persistWindowSize()
        showMain()
    }
    @objc func quit() { NSApp.terminate(nil) }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if store.settings.compact { showCompact() } else { showMain() }
        return true
    }

    func showMain(preserveSettings: Bool = false) {
        if !preserveSettings { showingSettings = false }
        store.settings.compact = false
        miniWindow.orderOut(nil)
        keepOnScreen(mainWindow)
        mainWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        schedulePoll()
    }

    func showCompact() {
        showingSettings = false
        store.settings.compact = true
        mainWindow.orderOut(nil)
        keepOnScreen(miniWindow)
        miniWindow.orderFrontRegardless()
        compactView.update()
        schedulePoll()
    }

    private func storeChanged() {
        guard mainWindow != nil else { return }
        applySettings()
        compactView.update()
        statusItem?.button?.toolTip = "Codex Glass · " + (selected.map { "\(Int(floor($0.remaining)))% " + Copy.period($0, language) } ?? t("offline"))
        deliverAlerts()
        schedulePoll()
    }

    private func applySettings() {
        let settings = store.settings
        guard settings != lastSettings else { return }
        let old = lastSettings
        lastSettings = settings
        let appearance: NSAppearance? = settings.theme == "dark" ? NSAppearance(named: .darkAqua) : settings.theme == "light" ? NSAppearance(named: .aqua) : nil
        mainWindow.appearance = appearance
        miniWindow.appearance = appearance
        mainWindow.level = settings.pinned ? .floating : .normal
        miniWindow.level = settings.pinned ? .floating : .normal
        if old?.language != settings.language { buildApplicationMenu() }
        if old?.refreshSeconds != settings.refreshSeconds { schedulePoll() }
    }

    func refresh() {
        guard !sleeping, pollTask == nil, !store.busy, !store.loginPending else { schedulePoll(); return }
        pollTimer?.invalidate()
        pollTask = Task {
            await store.refresh()
            guard !Task.isCancelled else { return }
            lastRefresh = Date()
            now = lastRefresh
            failures = store.status == "live" ? 0 : min(failures + 1, 5)
            pollTask = nil
            compactView.update()
            schedulePoll()
        }
    }

    private func schedulePoll() {
        pollTimer?.invalidate()
        guard !sleeping, !closing, !smoke, !store.loginPending, !store.busy, pollTask == nil else { return }
        let visible = (mainWindow?.isVisible == true && mainWindow?.isMiniaturized == false) || miniWindow?.isVisible == true
        let base = visible ? store.settings.refreshSeconds : max(600, store.settings.refreshSeconds)
        let interval = min(1800, Double(base) * pow(2, Double(failures)))
        pollTimer = Timer.scheduledTimer(withTimeInterval: max(1, interval - Date().timeIntervalSince(lastRefresh)), repeats: false) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.refresh() }
        }
        pollTimer?.tolerance = 5
    }

    private func clockTick() {
        guard !sleeping else { return }
        if mainWindow.isVisible || miniWindow.isVisible {
            now = Date()
            compactView.update()
        }
        if (mainWindow.isVisible || miniWindow.isVisible), let windows = store.snapshot?.windows, windows.contains(where: { $0.resetsAt.map { $0 <= now } ?? false }), Date().timeIntervalSince(lastRefresh) >= Double(store.settings.refreshSeconds) {
            refresh()
        }
    }

    @objc private func willSleep() {
        sleeping = true
        pollTimer?.invalidate()
        pollTask?.cancel()
        pollTask = nil
        store.suspend()
    }

    @objc private func didWake() {
        sleeping = false
        now = Date()
        failures = 0
        store.resume()
        refresh()
    }

    @objc private func screenChanged() { keepOnScreen(mainWindow); keepOnScreen(miniWindow) }

    private func keepOnScreen(_ window: NSWindow) {
        let screens = NSScreen.screens.map(\.visibleFrame)
        guard !screens.contains(where: { $0.contains(window.frame) }), let area = (window.screen ?? NSScreen.main)?.visibleFrame else { return }
        var frame = window.frame
        frame.size.width = min(frame.width, area.width)
        frame.size.height = min(frame.height, area.height)
        frame.origin.x = min(max(frame.minX, area.minX), area.maxX - frame.width)
        frame.origin.y = min(max(frame.minY, area.minY), area.maxY - frame.height)
        window.setFrame(frame, display: true)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool { sender.orderOut(nil); schedulePoll(); return false }
    func windowDidEndLiveResize(_ notification: Notification) { persistWindowSize() }
    func windowDidMiniaturize(_ notification: Notification) { schedulePoll() }
    func windowDidDeminiaturize(_ notification: Notification) { schedulePoll() }
    private func persistWindowSize() {
        guard let size = mainWindow.contentView?.bounds.size else { return }
        store.settings.mainWidth = size.width
        store.settings.mainHeight = size.height
    }

    func setStartup(_ enabled: Bool) {
        guard Bundle.main.bundleURL.pathExtension == "app", !smoke, !demo else {
            platformError = Copy.platform("Launch at sign-in is available in the installed app.", "安装应用后可设置开机启动。", "安裝應用程式後可設定登入時啟動。", language)
            return
        }
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            store.settings.startup = SMAppService.mainApp.status == .enabled
            if enabled && SMAppService.mainApp.status == .requiresApproval {
                platformError = Copy.platform("Allow Codex Glass in System Settings → General → Login Items.", "请在系统设置 → 通用 → 登录项中允许 Codex Glass。", "請在系統設定 → 一般 → 登入項目中允許 Codex Glass。", language)
                SMAppService.openSystemSettingsLoginItems()
            }
        } catch { platformError = error.localizedDescription }
    }

    func setNotifications(_ enabled: Bool) {
        if !enabled { store.settings.notifications = false; return }
        guard Bundle.main.bundleIdentifier != nil, !demo else { return }
        Task {
            do {
                let allowed = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
                store.settings.notifications = allowed
                if !allowed { platformError = Copy.platform("Enable notifications for Codex Glass in System Settings.", "请在系统设置中允许 Codex Glass 通知。", "請在系統設定中允許 Codex Glass 通知。", language) }
            } catch { platformError = error.localizedDescription }
        }
    }

    private func deliverAlerts() {
        guard !demo, store.settings.notifications, store.status == "live", let snapshot = store.snapshot, let identity = snapshot.identity else { return }
        for quota in snapshot.windows where quota.group == "codex" && quota.remaining <= 25 && (quota.resetsAt.map { $0 > Date() } ?? true) {
            let level = quota.remaining <= 10 ? 10 : 25
            notify(key: identity + quota.id + String(quota.resetsAt?.timeIntervalSince1970 ?? 0) + "-\(level)", body: Copy.period(quota, language) + ": \(Int(floor(quota.remaining)))% " + t("remaining"))
        }
        if let expiry = snapshot.resets.expiresAt, (snapshot.resets.count ?? 0) > 0, expiry > Date(), expiry.timeIntervalSinceNow <= 3 * 86400 {
            notify(key: identity + "reset-" + Copy.day(expiry), body: t("resetAlert"))
        }
        if let member = store.settings.membership[identity], let date = Copy.date(member.date), let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: date).day, (0...3).contains(days) {
            notify(key: identity + "member-" + member.date + "-\(days)", body: t("memberAlert").replacingOccurrences(of: "{0}", with: String(days)))
        }
    }

    private func notify(key: String, body: String) {
        // Only hashed account IDs and event identifiers are retained, never account credentials.
        var ledger = UserDefaults.standard.stringArray(forKey: "deliveredAlerts") ?? []
        guard !ledger.contains(key), notificationKeys.insert(key).inserted else { return }
        ledger.append(key)
        if ledger.count > 200 { ledger = Array(ledger.suffix(200)) }
        UserDefaults.standard.set(ledger, forKey: "deliveredAlerts")
        let content = UNMutableNotificationContent()
        content.title = "Codex Glass"
        content.body = body
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !closing else { return .terminateNow }
        closing = true
        pollTimer?.invalidate()
        clockTimer?.invalidate()
        pollTask?.cancel()
        store.shutdown()
        return .terminateNow
    }

    private func runSmokeTest() async {
        do {
            let directory = smokeDirectory ?? FileManager.default.temporaryDirectory.appendingPathComponent("CodexGlassSmoke")
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            await store.refresh()
            await store.readDaily()
            guard store.snapshot != nil, store.daily != nil else { throw SmokeError.failed("Demo data missing") }
            store.settings.language = "en"
            store.settings.theme = "light"
            store.settings.elapsedArc = true
            showMain()
            dailyOpen = true
            otherOpen = true
            mainWindow.setContentSize(NSSize(width: 382, height: 900))
            try await pauseForLayout()
            try capture(mainWindow, to: directory.appendingPathComponent("overview-en.png"))
            store.settings.language = "zh"
            otherOpen = false
            smokeChartRange = 7
            smokeChartDay = 6
            try await pauseForLayout()
            try capture(mainWindow, to: directory.appendingPathComponent("tokens-zh-7.png"))
            smokeChartRange = 30
            smokeChartDay = 29
            try await pauseForLayout()
            try capture(mainWindow, to: directory.appendingPathComponent("tokens-zh-30.png"))
            smokeChartRange = 7
            smokeChartDay = nil
            otherOpen = true
            try await pauseForLayout()
            try capture(mainWindow, to: directory.appendingPathComponent("overview-zh.png"))
            store.settings.language = "zh-TW"
            try await pauseForLayout()
            try capture(mainWindow, to: directory.appendingPathComponent("overview-zh-TW.png"))
            openSettings()
            try await pauseForLayout()
            try capture(mainWindow, to: directory.appendingPathComponent("settings.png"))
            store.settings.theme = "dark"
            showMain()
            try await pauseForLayout()
            try capture(mainWindow, to: directory.appendingPathComponent("overview-dark.png"))
            showCompact()
            compactView.setRevealed(true, animate: false)
            try await pauseForLayout()
            try capture(miniWindow, to: directory.appendingPathComponent("mini-hover.png"))
            compactView.setRevealed(false, animate: false)
            try capture(miniWindow, to: directory.appendingPathComponent("mini-idle.png"))
            guard mainWindow.styleMask.contains(.resizable), mainWindow.contentMinSize.width == 320,
                  miniWindow.contentView?.bounds.size == NSSize(width: 92, height: 126), !miniWindow.isOpaque,
                  t("title") != "title", AppResources.bundle.url(forResource: "icon", withExtension: "png") != nil else { throw SmokeError.failed("Window or bundled resource assertion failed") }
            try "{\"success\":true,\"demoOnly\":true,\"screenshots\":9,\"languages\":3,\"chartRanges\":[7,30],\"resizable\":true,\"transparentMini\":true}".write(to: directory.appendingPathComponent("ui-result.json"), atomically: true, encoding: .utf8)
            store.shutdown()
            NSApp.stop(nil)
            exit(0)
        } catch {
            if let smokeDirectory { try? "{\"success\":false}".write(to: smokeDirectory.appendingPathComponent("ui-result.json"), atomically: true, encoding: .utf8) }
            fputs("UI smoke failed: \(error)\n", stderr)
            store.shutdown()
            exit(1)
        }
    }

    private func pauseForLayout() async throws {
        try await Task.sleep(nanoseconds: 350_000_000)
        mainWindow.contentView?.layoutSubtreeIfNeeded()
        miniWindow.contentView?.layoutSubtreeIfNeeded()
    }

    private func capture(_ window: NSWindow, to destination: URL) throws {
        guard let view = window.contentView, let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { throw SmokeError.failed("Cannot allocate screenshot") }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        guard let png = bitmap.representation(using: .png, properties: [:]) else { throw SmokeError.failed("Cannot encode screenshot") }
        try png.write(to: destination)
    }

    enum SmokeError: Error { case failed(String) }
}

final class MiniPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
