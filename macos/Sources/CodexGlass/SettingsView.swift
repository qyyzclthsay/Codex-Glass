import AppKit
import SwiftUI
import CodexGlassCore

struct SettingsView: View {
    @ObservedObject var controller: AppCoordinator
    @ObservedObject var store: UsageStore
    private var language: String { store.settings.language }
    private func t(_ key: String) -> String { Copy.text(key, language) }
    private let presets = ["#4F8DF7", "#8954F6", "#16A085", "#ED729C", "#F59E0B", "#64748B"]

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            section(t("appearance")) {
                VStack(spacing: 14) {
                    Picker(t("language"), selection: $store.settings.language) {
                        Text("English").tag("en")
                        Text("简体中文").tag("zh")
                        Text("繁體中文").tag("zh-TW")
                    }
                    Divider()
                    Picker(t("theme"), selection: $store.settings.theme) {
                        Text(t("system")).tag("system")
                        Text(t("light")).tag("light")
                        Text(t("dark")).tag("dark")
                    }
                }
            }
            section(t("accentColor")) {
                VStack(alignment: .leading, spacing: 14) {
                    ColorPicker(selection: Binding(get: { store.settings.accent }, set: { store.settings.accentColor = NSColor($0).glassHex }), supportsOpacity: false) {
                        settingLabel(t("accentColor"), help: t("accentHelp"))
                    }
                    Divider()
                    HStack(spacing: 9) {
                        ForEach(presets, id: \.self) { hex in
                            Button { store.settings.accentColor = hex } label: {
                                Circle().fill(Color(nsColor: NSColor(glassHex: hex))).frame(width: 20, height: 20)
                                    .padding(2).overlay(Circle().strokeBorder((store.settings.accentColor ?? "#4F8DF7").uppercased() == hex.uppercased() ? Color.primary.opacity(0.5) : Color.clear, lineWidth: 1))
                            }.buttonStyle(.plain).help(hex).accessibilityLabel(t("accentColor") + " " + hex)
                        }
                        Spacer(minLength: 0)
                    }
                    Button(t("resetAccent")) { store.settings.accentColor = nil }.buttonStyle(.plain).foregroundStyle(store.settings.accent).font(.system(size: 10))
                }
            }
            section(t("ringSettings")) {
                VStack(spacing: 16) {
                    HStack(alignment: .center, spacing: 12) {
                        settingLabel(t("ringWindow"), help: t("ringWindowHelp"))
                        Spacer(minLength: 0)
                        Picker(t("ringWindow"), selection: $store.settings.ringWindow) {
                            Text(t("auto")).tag("auto")
                            Text(t("five")).tag("five")
                            Text(t("week")).tag("week")
                        }.labelsHidden().frame(maxWidth: 116)
                    }
                    Divider()
                    Toggle(isOn: $store.settings.elapsedArc) { settingLabel(t("elapsedArc"), help: t("elapsedArcHelp")) }.toggleStyle(.switch).controlSize(.small)
                }
            }
            section(t("behavior")) {
                VStack(spacing: 16) {
                    Toggle(isOn: Binding(get: { store.settings.startup }, set: { controller.setStartup($0) })) {
                        settingLabel(t("startup"), help: Copy.platform("Available from the menu bar after sign-in", "登录后可从菜单栏打开", "登入後可從選單列開啟", language))
                    }.toggleStyle(.switch).controlSize(.small).disabled(controller.demo)
                    Divider()
                    Toggle(isOn: Binding(get: { store.settings.notifications }, set: { controller.setNotifications($0) })) {
                        settingLabel(t("notifications"), help: t("notificationsHelp"))
                    }.toggleStyle(.switch).controlSize(.small).disabled(controller.demo)
                    Divider()
                    Picker(t("interval"), selection: $store.settings.refreshSeconds) {
                        Text(t("everyMinute")).tag(60)
                        Text(t("every2")).tag(120)
                        Text(t("every5")).tag(300)
                        Text(t("every10")).tag(600)
                    }
                    Text(Copy.platform("Queries existing statistics; no AI model calls or extra tokens.", "仅查询已有用量，不调用 AI 模型，不额外消耗 Token。", "僅查詢既有用量，不呼叫 AI 模型，不額外消耗 Token。", language)).font(.system(size: 10)).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading).fixedSize(horizontal: false, vertical: true)
                }
            }
            section(t("membership")) { MembershipEditor(store: store) }
            section(t("account")) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(t("privacy")).fixedSize(horizontal: false, vertical: true)
                    Button(t("retry")) { controller.refresh() }.buttonStyle(.plain).foregroundStyle(store.settings.accent).disabled(store.busy || store.loginPending)
                    if store.loginPending {
                        Text(t("browserWaiting")).foregroundStyle(.secondary)
                        Button(t("cancel")) { Task { await store.cancelLogin() } }
                    } else {
                        Button(t("connect")) {
                            Task { if let url = await store.login() { NSWorkspace.shared.open(url) } }
                        }.buttonStyle(.plain).foregroundStyle(store.settings.accent).disabled(store.busy)
                    }
                    Text(t("sharedLogin")).font(.system(size: 10)).foregroundStyle(.secondary)
                }.font(.system(size: 11))
            }
            VStack(alignment: .leading, spacing: 7) {
                Text("Codex Glass " + (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.6.0-beta.1")).font(.system(size: 11, weight: .medium))
                Text(t("developer")).font(.system(size: 10)).foregroundStyle(.secondary)
                Link("GitHub · MIT", destination: URL(string: "https://github.com/qyyzclthsay/Codex-Glass")!).font(.system(size: 11))
            }.padding(.horizontal, 3)
        }.font(.system(size: 12))
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary).padding(.leading, 1)
            Card { content() }
        }
    }

    private func settingLabel(_ title: String, help: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.system(size: 12))
            Text(help).font(.system(size: 10)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct MembershipEditor: View {
    @ObservedObject var store: UsageStore
    @State private var date = Date()
    @State private var kind = "renewal"
    @State private var saved = false
    private var identity: String? { store.snapshot?.identity }
    private func t(_ key: String) -> String { Copy.text(key, store.settings.language) }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text(t("memberHelp")).font(.system(size: 10)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if identity != nil {
                Picker(t("dateKind"), selection: $kind) {
                    Text(t("renewal")).tag("renewal")
                    Text(t("expiry")).tag("expiry")
                }
                Divider()
                DatePicker(t("date"), selection: $date, displayedComponents: .date).datePickerStyle(.field)
                HStack {
                    Button(t("save")) {
                        guard let identity else { return }
                        store.settings.membership[identity] = MembershipDate(date: Copy.day(date), kind: kind)
                        saved = true
                    }.buttonStyle(.borderedProminent)
                    Button(t("clear")) {
                        guard let identity else { return }
                        store.settings.membership.removeValue(forKey: identity)
                        saved = false
                    }.buttonStyle(.plain).foregroundStyle(.secondary)
                    Spacer()
                    if saved { Text(t("saved")).font(.caption2).foregroundStyle(.secondary) }
                }
            } else { Text(t("connectFirst")).font(.callout).foregroundStyle(.secondary) }
        }
        .onAppear(perform: load)
        .onChange(of: identity) { _ in load() }
        .onChange(of: date) { _ in saved = false }
        .onChange(of: kind) { _ in saved = false }
    }

    private func load() {
        let member = identity.flatMap { store.settings.membership[$0] }
        date = member.flatMap { Copy.date($0.date) } ?? Date()
        kind = member?.kind ?? "renewal"
        saved = false
    }
}
