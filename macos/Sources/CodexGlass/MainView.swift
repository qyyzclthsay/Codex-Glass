import AppKit
import SwiftUI
import CodexGlassCore

struct MainView: View {
    @ObservedObject var controller: AppCoordinator
    @ObservedObject var store: UsageStore
    @Environment(\.colorScheme) private var scheme
    private var language: String { store.settings.language }
    private func t(_ key: String) -> String { Copy.text(key, language) }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView(.vertical) {
                if controller.showingSettings {
                    SettingsView(controller: controller, store: store).padding(18)
                } else {
                    overview.padding(20)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            footer
        }
        .background(LinearGradient(colors: scheme == .dark ? [Color(nsColor: NSColor(glassHex: "#213045")), Color(nsColor: NSColor(glassHex: "#19293B"))] : [Color(nsColor: NSColor(glassHex: "#FAFCFF")), Color(nsColor: NSColor(glassHex: "#EAF3FF"))], startPoint: .topLeading, endPoint: .bottomTrailing))
        .tint(store.settings.accent)
        .accentColor(store.settings.accent)
        .preferredColorScheme(store.settings.scheme)
        .frame(minWidth: 320, minHeight: 360)
        .onExitCommand { controller.showingSettings = false }
        .alert(Copy.platform("Codex Glass", "Codex Glass", "Codex Glass", language), isPresented: Binding(get: { controller.platformError != nil }, set: { if !$0 { controller.platformError = nil } })) {
            Button("OK") { controller.platformError = nil }
        } message: { Text(controller.platformError ?? "") }
    }

    private var header: some View {
        HStack(spacing: 4) {
            if controller.showingSettings {
                IconButton(symbol: "chevron.left", label: t("back")) { controller.showingSettings = false }
                Text(t("settingsTitle")).font(.system(size: 12, weight: .semibold))
            } else {
                Text("Codex Glass").font(.system(size: 12, weight: .semibold))
            }
            Spacer(minLength: 4)
            Menu {
                Button("English") { store.settings.language = "en" }
                Button("简体中文") { store.settings.language = "zh" }
                Button("繁體中文") { store.settings.language = "zh-TW" }
            } label: {
                Text(language == "en" ? "EN" : language == "zh" ? "简" : "繁").font(.system(size: 10, weight: .medium))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help(t("language"))
            IconButton(symbol: store.settings.pinned ? "pin.fill" : "pin", label: t(store.settings.pinned ? "unpin" : "pin"), active: store.settings.pinned) { store.settings.pinned.toggle() }
            IconButton(symbol: "gearshape", label: t("settings"), active: controller.showingSettings) { controller.showingSettings.toggle() }
            IconButton(symbol: "rectangle.inset.filled.and.person.filled", label: t("compact")) { controller.showCompact() }
        }
        .padding(.leading, 76)
        .padding(.trailing, 10)
        .frame(height: 48)
    }

    private var overview: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text(t("title")).font(.system(size: 23, weight: .bold))
                Spacer()
                if let plan = store.snapshot?.plan {
                    Text(plan.capitalized).font(.system(size: 10, weight: .medium)).padding(.horizontal, 10).padding(.vertical, 5)
                        .foregroundStyle(store.settings.accent)
                        .background(store.settings.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 7))
                }
            }
            if controller.demo {
                Text(t("demo")).font(.caption2).foregroundStyle(.secondary)
            }
            if let snapshot = store.snapshot {
                ForEach(snapshot.windows.filter { $0.group == "codex" }) { quota in
                    QuotaCard(quota: quota, store: store, now: controller.now, primary: true)
                }
                if snapshot.windows.filter({ $0.group == "codex" }).isEmpty { Text(t("noWindows")).font(.callout).foregroundStyle(.secondary) }
                otherPools(snapshot)
                Divider()
                DisclosureGroup(isExpanded: $controller.dailyOpen) {
                    DailyView(store: store, now: controller.now).padding(.top, 14)
                } label: {
                    Label(t("dailyTokens"), systemImage: "chart.bar.xaxis").font(.system(size: 12, weight: .medium))
                }
                Divider()
                resetCredits(snapshot)
                Divider()
                membership(snapshot)
            } else { connection }
            if let error = store.error, store.snapshot != nil {
                Label(t(error), systemImage: "exclamationmark.circle").font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private func otherPools(_ snapshot: UsageSnapshot) -> some View {
        let others = snapshot.windows.filter { $0.group != "codex" }
        let groups = Dictionary(grouping: others, by: \.group)
        if !others.isEmpty {
            Divider()
            DisclosureGroup(isExpanded: $controller.otherOpen) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(t("poolHelp")).font(.system(size: 10)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true).padding(.bottom, 3)
                    ForEach(groups.keys.sorted(), id: \.self) { key in
                        if let windows = groups[key] {
                            Text(windows.first?.model ?? key).font(.system(size: 11, weight: .medium)).padding(.top, 2)
                            ForEach(windows) { quota in QuotaCard(quota: quota, store: store, now: controller.now, primary: false) }
                        }
                    }
                }.padding(.top, 14)
            } label: {
                HStack {
                    Text(t("otherPools"))
                    Spacer()
                    Text("\(groups.count)").padding(.horizontal, 5).background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 4))
                }.font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
    }

    private func resetCredits(_ snapshot: UsageSnapshot) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "bolt").foregroundStyle(store.settings.accent).frame(width: 30, height: 32).background(store.settings.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 4) {
                Text(t("resetCredits")).font(.system(size: 12, weight: .medium))
                if let expiry = snapshot.resets.expiresAt {
                    Text(Copy.day(expiry) + " " + t("expires")).font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 4)
            Text(snapshot.resets.count.map(String.init) ?? "—").font(.system(size: 24, weight: .semibold))
            Button { controller.openUsage() } label: {
                Label(t("resetAction"), systemImage: "arrow.up.right").font(.system(size: 10))
            }.buttonStyle(.plain).foregroundStyle(store.settings.accent).help(t("resetHelp"))
        }.padding(.vertical, 4)
    }

    private func membership(_ snapshot: UsageSnapshot) -> some View {
        let member = snapshot.identity.flatMap { store.settings.membership[$0] }
        return HStack(spacing: 11) {
            Image(systemName: "calendar").foregroundStyle(.secondary).frame(width: 30)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Text(t(member?.kind ?? "membership"))
                    if member != nil { Text(t("manualShort")).font(.system(size: 8)).padding(.horizontal, 3).overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.secondary.opacity(0.3))) }
                }.font(.system(size: 11)).foregroundStyle(.secondary)
                Text(member?.date ?? t("unknown")).font(.system(size: 12, weight: .semibold))
                if let date = member.flatMap({ Copy.date($0.date) }), let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: controller.now), to: date).day {
                    Text(days < 0 ? t("datePassed") : days == 0 ? t("today") : "\(days) " + t("daysLeft")).font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button(t(member == nil ? "setDate" : "edit")) { controller.openSettings() }.buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(store.settings.accent)
        }.padding(.vertical, 4)
    }

    private var connection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(t("connectTitle")).font(.system(size: 17, weight: .semibold))
            Text(t("connectBody")).font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if store.busy {
                HStack(spacing: 9) { ProgressView().controlSize(.small); Text(t("syncing")).font(.callout) }.padding(.vertical, 10)
            } else if store.loginPending {
                Text(t("browserWaiting")).font(.callout)
                Button(t("cancel")) { Task { await store.cancelLogin() } }
            } else {
                if let error = store.error { Text(t(error)).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
                Button(t("connect")) {
                    Task { if let url = await store.login() { NSWorkspace.shared.open(url) } }
                }.buttonStyle(.borderedProminent)
                Button(t("retry")) { controller.refresh() }.buttonStyle(.plain).foregroundStyle(store.settings.accent)
                if store.error == "codexMissing" {
                    Link(t("install"), destination: URL(string: "https://developers.openai.com/codex/quickstart")!).font(.caption)
                }
            }
            Text(t("sharedLogin")).font(.system(size: 10)).foregroundStyle(.secondary).padding(.top, 4)
        }.padding(.vertical, 10)
    }

    private var footer: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 5) {
                Circle().fill(store.status == "live" ? Color.green.opacity(0.7) : Color.secondary).frame(width: 5, height: 5)
                Text(t(store.busy ? "syncing" : store.status == "live" ? "live" : store.status == "stale" ? "stale" : "offline"))
                if let snapshot = store.snapshot {
                    let minutes = max(0, Int(controller.now.timeIntervalSince(snapshot.observedAt) / 60))
                    Text(minutes == 0 ? t("justNow") : "\(minutes) " + t("minutesAgo")).lineLimit(1)
                }
                Spacer(minLength: 5)
                IconButton(symbol: "arrow.clockwise", label: t("refresh")) { controller.refresh() }.disabled(store.busy || store.loginPending)
                IconButton(symbol: "arrow.up.right.square", label: t("usage")) { controller.openUsage() }
            }.font(.system(size: 10)).foregroundStyle(.secondary).padding(.horizontal, 16).frame(height: 42)
        }
    }
}

struct QuotaCard: View {
    let quota: QuotaWindow
    @ObservedObject var store: UsageStore
    let now: Date
    let primary: Bool
    private var expired: Bool { quota.resetsAt.map { $0 <= now } ?? false }
    private var language: String { store.settings.language }
    private func t(_ key: String) -> String { Copy.text(key, language) }

    var body: some View {
        Card(highlighted: primary) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 7) {
                    Image(systemName: "calendar").foregroundStyle(.secondary)
                    Text(Copy.period(quota, language)).fontWeight(.semibold)
                    if let scope = quota.scope { Text(scope).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1) }
                    Spacer()
                    Text(t("remaining")).font(.system(size: 10)).foregroundStyle(.secondary)
                }.font(.system(size: 12))
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(expired ? "—" : "\(Int(floor(quota.remaining)))").font(.system(size: 40, weight: .semibold, design: .rounded)).monospacedDigit()
                    if !expired {
                        Text("%").font(.system(size: 21)).foregroundStyle(.secondary)
                        Text(t("remaining")).font(.system(size: 10)).foregroundStyle(.secondary).padding(.leading, 5)
                    }
                }
                GeometryReader { geometry in
                    Capsule().fill(Color.secondary.opacity(0.12))
                    Capsule().fill(quota.remaining <= 10 ? Color.red.opacity(0.7) : quota.remaining <= 25 ? Color.orange : store.settings.accent)
                        .frame(width: geometry.size.width * (expired ? 0 : min(1, max(0, quota.remaining / 100))))
                }.frame(height: 5).accessibilityHidden(true)
                HStack {
                    Text(Copy.countdown(quota, now: now, language: language)).font(.system(size: 10)).foregroundStyle(.secondary)
                    Spacer()
                    if primary && (quota.minutes == 300 || quota.minutes == 10080) {
                        let choice = quota.minutes == 300 ? "five" : "week"
                        IconButton(symbol: store.settings.ringWindow == choice ? "pin.fill" : "pin", label: t("pinWindow"), active: store.settings.ringWindow == choice) {
                            store.settings.ringWindow = store.settings.ringWindow == choice ? "auto" : choice
                        }.scaleEffect(0.75).frame(width: 20, height: 15)
                    }
                }
                if quota.groupBlocked { Text(t("blocked")).font(.caption2).foregroundStyle(.secondary) }
            }
        }
    }
}

struct DailyView: View {
    @ObservedObject var store: UsageStore
    var now: Date
    @State private var range = 7
    @State private var selected: Int?
    private var language: String { store.settings.language }
    private var days: [DailyRecord] { UsageMath.series(usage: store.daily, range: range, today: now) }
    private var total: Double? {
        let values = days.compactMap(\.tokens)
        return values.isEmpty ? nil : values.reduce(0, +)
    }
    private func t(_ key: String) -> String { Copy.text(key, language) }

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Picker(t("dayRange"), selection: $range) {
                    Text("7" + t("dayRange")).tag(7)
                    Text("30" + t("dayRange")).tag(30)
                }.pickerStyle(.segmented).frame(width: 126).labelsHidden()
                Spacer()
                Button(t("dailyRefresh")) { Task { await store.readDaily() } }.buttonStyle(.plain).foregroundStyle(store.settings.accent).font(.system(size: 10)).disabled(store.dailyBusy)
            }
            HStack {
                Text(t("periodTokens")).font(.system(size: 10)).foregroundStyle(.secondary)
                Spacer()
                Text(UsageMath.tokens(total, language: language, total: true)).font(.system(size: 17, weight: .semibold)).monospacedDigit()
                    .help(total.map { $0.formatted(.number.precision(.fractionLength(0))) + " tokens" } ?? t("unknown"))
            }
            chart
            if store.dailyBusy { ProgressView().controlSize(.small) }
            if let error = store.dailyError { Text(t(error)).font(.caption2).foregroundStyle(.secondary) }
            if store.daily != nil && total == nil { Text(t("noDaily")).font(.caption2).foregroundStyle(.secondary) }
            Text(t("dailySource")).font(.system(size: 10)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if store.daily?.incomplete == true { Text(t("partialDaily")).font(.caption2).foregroundStyle(.secondary) }
        }
        .task { if store.daily == nil { await store.readDaily() } }
        .onChange(of: range) { _ in selected = nil }
    }

    private var chart: some View {
        VStack(spacing: 6) {
            HStack {
                Spacer()
                if let selected, days.indices.contains(selected) {
                    let item = days[selected]
                    Text(item.date + " · " + UsageMath.tokens(item.tokens, language: language) + (item.tokens == nil ? "" : " tokens"))
                        .font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
                }
            }.frame(height: 13)
            GeometryReader { geometry in
                let maximum = max(1, days.compactMap(\.tokens).max() ?? 1)
                let gap: CGFloat = range == 7 ? 3 : 2
                let width = max(1, (geometry.size.width - gap * CGFloat(max(0, days.count - 1))) / CGFloat(max(1, days.count)))
                HStack(alignment: .bottom, spacing: gap) {
                    ForEach(Array(days.enumerated()), id: \.element.id) { index, item in
                        VStack(spacing: 0) {
                            Spacer(minLength: 0)
                            if let tokens = item.tokens {
                                RoundedRectangle(cornerRadius: 1.5).fill(store.settings.accent.opacity(selected == nil || selected == index ? 1 : 0.7))
                                    .frame(height: max(2, geometry.size.height * tokens / maximum))
                            } else {
                                Rectangle().fill(Color.secondary.opacity(0.35)).frame(height: 1)
                            }
                        }
                        .frame(width: width)
                        .contentShape(Rectangle())
                        .onHover { hovering in if hovering { selected = index } }
                        .onTapGesture { selected = index }
                        .accessibilityElement()
                        .accessibilityLabel(item.date + ", " + UsageMath.tokens(item.tokens, language: language) + (item.tokens == nil ? "" : " tokens"))
                    }
                }
                .onHover { hovering in if !hovering { selected = nil } }
            }.frame(height: 90)
            HStack {
                Text(String(days.first?.date.suffix(5) ?? ""))
                Spacer()
                Text(String(days.last?.date.suffix(5) ?? ""))
            }.font(.system(size: 9)).foregroundStyle(.secondary)
        }
        .focusable()
        .onMoveCommand { direction in
            guard !days.isEmpty else { return }
            let delta = direction == .left ? -1 : direction == .right ? 1 : 0
            selected = ((selected ?? (delta > 0 ? -1 : 0)) + delta + days.count) % days.count
        }
        .accessibilityLabel(t("dailyTokens"))
    }
}
