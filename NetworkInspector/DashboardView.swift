import SwiftUI
import NetworkInspectorKit

/// Per-app live traffic dashboard: headline totals, a sort bar, and a ranked
/// list of apps that reshuffles as traffic flows in.
struct AppStatsDashboardView: View {
    @Bindable var model: LiveTrafficModel
    let internetAccess: InternetAccessController

    @State private var showsInternetAccess = false

    var body: some View {
        let ranked = model.rankedStats
        let kind = model.kind

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    SummaryGrid(summary: model.summary, kind: kind)

                    SortBar(selection: $model.sortOrder, kind: kind)

                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeader(title: "Apps", detail: "\(ranked.count) tracked")

                        LazyVStack(spacing: 10) {
                            ForEach(Array(ranked.enumerated()), id: \.element.id) { index, stats in
                                NavigationLink(value: stats.app) {
                                    AppStatsRow(
                                        rank: index + 1,
                                        stats: stats,
                                        sortOrder: model.sortOrder,
                                        kind: kind,
                                        share: model.summary.share(of: stats),
                                        isInternetBlocked: internetAccess.isBlocked(stats.app),
                                        isFilterActive: internetAccess.isFilterActive
                                    )
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    InternetAccessToggle(controller: internetAccess, app: stats.app)
                                }
                                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                            }
                        }
                        .animation(.spring(duration: 0.5, bounce: 0.18), value: ranked.map(\.id))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(DashboardBackground())
            .overlay {
                if ranked.isEmpty {
                    switch model.source {
                    case .device:
                        CaptureStatusView(controller: internetAccess) {
                            model.setSource(.demo)
                        }
                    case .demo:
                        ContentUnavailableView(
                            "No Traffic Yet",
                            systemImage: "antenna.radiowaves.left.and.right",
                            description: Text("Requests will appear here as apps talk to the network.")
                        )
                    }
                }
            }
            .navigationTitle("Live Traffic")
            .navigationDestination(for: SourceApp.self) { app in
                AppTrafficList(model: model, app: app)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            InternetAccessToggle(controller: internetAccess, app: app)
                        }
                    }
            }
            .sheet(isPresented: $showsInternetAccess) {
                InternetAccessView(controller: internetAccess, knownApps: model.stats.map(\.app))
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    LiveIndicator(status: feedStatus)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        if model.source == .device {
                            Button(internetAccess.capturesTraffic ? "Stop Capturing" : "Start Capturing",
                                   systemImage: internetAccess.capturesTraffic ? "stop.circle" : "record.circle") {
                                internetAccess.setCapturesTraffic(!internetAccess.capturesTraffic)
                            }
                        }
                        Button(model.source == .demo ? "Show Device Traffic" : "Show Demo Traffic",
                               systemImage: model.source == .demo ? "iphone" : "wand.and.stars") {
                            model.setSource(model.source == .demo ? .device : .demo)
                        }
                        Button(model.isLive ? "Pause Updates" : "Resume Updates",
                               systemImage: model.isLive ? "pause.fill" : "play.fill") {
                            model.isLive.toggle()
                        }
                        Button("Internet Access…", systemImage: "wifi.slash") {
                            showsInternetAccess = true
                        }
                        Button("Clear Traffic", systemImage: "trash", role: .destructive) {
                            model.clear()
                        }
                    } label: {
                        Label("Options", systemImage: "ellipsis")
                    }
                }
            }
        }
    }

    private var feedStatus: FeedStatus {
        if !model.isLive { return .paused }
        if model.source == .demo { return .demo }
        return internetAccess.isCapturing ? .live : .off
    }
}

/// One app's traffic: its captured connections, or its requests in demo mode.
private struct AppTrafficList: View {
    let model: LiveTrafficModel
    let app: SourceApp

    var body: some View {
        let title = model.current(app).displayName
        switch model.source {
        case .device:
            ConnectionListView(title: title, connections: model.connections(for: app), showsApp: false)
        case .demo:
            RequestListView(title: title, entries: model.requests(for: app), showsApp: false)
        }
    }
}

// MARK: - Capture

/// What the dashboard shows before any real traffic arrives: how to start
/// capturing, why capture isn't running, or that it's waiting for traffic.
private struct CaptureStatusView: View {
    let controller: InternetAccessController
    let showDemo: () -> Void

    var body: some View {
        if !controller.capturesTraffic {
            ContentUnavailableView {
                Label("See Which Apps Use the Network", systemImage: "antenna.radiowaves.left.and.right")
            } description: {
                Text("Capture lists every connection apps like WhatsApp or Safari make, by app. "
                    + "It runs as a content filter, so iOS asks for permission first.")
            } actions: {
                Button("Start Capturing") {
                    controller.setCapturesTraffic(true)
                }
                .buttonStyle(.borderedProminent)
                Button("Show Demo Traffic", action: showDemo)
            }
        } else {
            switch controller.filterState {
            case .unknown:
                ContentUnavailableView("Starting Capture…", systemImage: "hourglass")
            case .on:
                ContentUnavailableView(
                    "Waiting for Traffic",
                    systemImage: "antenna.radiowaves.left.and.right",
                    description: Text("Use any app and its connections show up here.")
                )
            case .off:
                ContentUnavailableView {
                    Label("Capture Is Off", systemImage: "shield.slash")
                } description: {
                    Text("The content filter isn't running. It may have been turned off in "
                        + "Settings ▸ General ▸ VPN & Device Management.")
                } actions: {
                    Button("Turn On Filter", action: controller.retry)
                        .buttonStyle(.borderedProminent)
                }
            case .failed(let message):
                ContentUnavailableView {
                    Label("Capture Unavailable", systemImage: "exclamationmark.shield.fill")
                } description: {
                    Text(message)
                } actions: {
                    Button("Try Again", action: controller.retry)
                    Button("Show Demo Traffic", action: showDemo)
                }
            }
        }
    }
}

// MARK: - Summary

private struct SummaryGrid: View {
    let summary: TrafficSummary
    let kind: TrafficKind

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            StatTile(
                title: "Throughput",
                value: Formatting.rate(perMinute: summary.requestsPerMinute),
                systemImage: "waveform.path.ecg",
                tint: .cyan,
                activity: summary.activity
            )
            StatTile(
                title: "Active Apps",
                value: "\(summary.activeAppCount)",
                systemImage: "app.connected.to.app.below.fill",
                tint: .indigo
            )
            StatTile(
                title: "Download",
                value: Formatting.speed(bytesPerSecond: summary.downloadBytesPerSecond),
                systemImage: "arrow.down.circle.fill",
                tint: .blue
            )
            StatTile(
                title: "Upload",
                value: Formatting.speed(bytesPerSecond: summary.uploadBytesPerSecond),
                systemImage: "arrow.up.circle.fill",
                tint: .purple
            )
            StatTile(
                title: "Transferred",
                value: Formatting.byteSize(summary.totalBytes),
                systemImage: "externaldrive.fill",
                tint: .mint
            )
            StatTile(
                title: kind == .connections ? "Blocked" : "Error Rate",
                value: Formatting.percent(summary.errorRate),
                systemImage: kind == .connections ? "hand.raised.fill" : "exclamationmark.triangle.fill",
                tint: summary.errorRate > 0.05 ? .red : .orange
            )
        }
    }
}

private struct StatTile: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color
    var activity: [Int] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .lastTextBaseline) {
                Text(value)
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 4)
                if !activity.isEmpty {
                    Sparkline(values: activity, tint: tint)
                        .frame(width: 56, height: 22)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: .rect(cornerRadius: 22))
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(tint.opacity(0.18), lineWidth: 1)
        }
        .animation(.snappy, value: value)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Sorting

private struct SortBar: View {
    @Binding var selection: AppStatsSortOrder
    let kind: TrafficKind

    var body: some View {
        ScrollView(.horizontal) {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(AppStatsSortOrder.allCases) { order in
                        let isSelected = order == selection
                        Button {
                            withAnimation(.spring(duration: 0.45, bounce: 0.2)) {
                                selection = order
                            }
                        } label: {
                            Label(order.label(for: kind), systemImage: order.systemImage)
                                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                                .foregroundStyle(isSelected ? Color.white : Color.primary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                        .glassEffect(
                            isSelected ? Glass.regular.tint(.accentColor).interactive() : Glass.regular.interactive(),
                            in: .capsule
                        )
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
        .sensoryFeedback(.selection, trigger: selection)
    }
}

private extension AppStatsSortOrder {
    var systemImage: String {
        switch self {
        case .activity: "bolt.fill"
        case .requests: "number"
        case .speed: "speedometer"
        case .data: "externaldrive.fill"
        case .errors: "exclamationmark.octagon.fill"
        case .latency: "timer"
        case .name: "textformat"
        }
    }
}

// MARK: - Rows

private struct AppStatsRow: View {
    let rank: Int
    let stats: AppTrafficStats
    let sortOrder: AppStatsSortOrder
    let kind: TrafficKind
    let share: Double
    let isInternetBlocked: Bool
    let isFilterActive: Bool

    private var tint: Color { stats.app.tint }

    var body: some View {
        let headline = stats.headline(for: sortOrder, kind: kind)

        HStack(spacing: 12) {
            Text("\(rank)")
                .font(.footnote.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(rank <= 3 ? AnyShapeStyle(tint) : AnyShapeStyle(HierarchicalShapeStyle.tertiary))
                .frame(width: 18)
                .contentTransition(.numericText())

            AppIcon(app: stats.app, size: 44)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(stats.app.displayName)
                        .font(.headline)
                        .lineLimit(1)
                    if isInternetBlocked {
                        BlockedIndicator(isEnforced: isFilterActive)
                            .font(.caption.weight(.bold))
                    } else if stats.isActive {
                        Circle()
                            .fill(.green)
                            .frame(width: 6, height: 6)
                            .accessibilityLabel("Active")
                    }
                }

                HStack(spacing: 10) {
                    Label("\(stats.requestCount)", systemImage: "arrow.left.arrow.right")
                    Label(Formatting.duration(seconds: stats.averageDurationSeconds), systemImage: "timer")
                    if stats.failureCount > 0 {
                        Label(Formatting.percent(stats.errorRate), systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(stats.errorRate > 0.05 ? Color.red : Color.orange)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .labelStyle(CompactLabelStyle())
                .monospacedDigit()

                HStack(spacing: 10) {
                    Label(Formatting.speed(bytesPerSecond: stats.downloadBytesPerSecond), systemImage: "arrow.down")
                        .foregroundStyle(Color.blue)
                    Label(Formatting.speed(bytesPerSecond: stats.uploadBytesPerSecond), systemImage: "arrow.up")
                        .foregroundStyle(Color.purple)
                }
                .font(.caption.weight(.medium))
                .labelStyle(CompactLabelStyle())
                .monospacedDigit()
                .contentTransition(.numericText())
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(
                    "Download \(Formatting.speed(bytesPerSecond: stats.downloadBytesPerSecond)), "
                        + "upload \(Formatting.speed(bytesPerSecond: stats.uploadBytesPerSecond))"
                )

                ShareBar(share: share, tint: tint)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                Text(headline.value)
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .lineLimit(1)
                Text(headline.caption)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Sparkline(values: stats.activity, tint: tint)
                    .frame(width: 64, height: 20)
            }
        }
        .padding(14)
        .background(.regularMaterial, in: .rect(cornerRadius: 22))
        .contentShape(.rect(cornerRadius: 22))
        .animation(.snappy, value: headline)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(rank). \(stats.app.displayName), \(headline.value) \(headline.caption)")
    }
}

private struct CompactLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 3) {
            configuration.icon.imageScale(.small)
            configuration.title
        }
    }
}

private struct ShareBar: View {
    let share: Double
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                Capsule()
                    .fill(tint.gradient)
                    .frame(width: max(4, proxy.size.width * min(max(share, 0), 1)))
            }
        }
        .frame(height: 4)
        .animation(.smooth, value: share)
        .accessibilityHidden(true)
    }
}

// MARK: - Chrome

private struct SectionHeader: View {
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.title3.weight(.semibold))
            Spacer()
            Text(detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 4)
    }
}

/// Where the dashboard's traffic is coming from right now.
private enum FeedStatus {
    /// Capturing real traffic on the device.
    case live
    /// Showing simulated traffic.
    case demo
    /// Updates paused by the user.
    case paused
    /// Showing device traffic, but capture isn't running.
    case off

    var title: String {
        switch self {
        case .live: "Live"
        case .demo: "Demo"
        case .paused: "Paused"
        case .off: "Not Capturing"
        }
    }

    var systemImage: String {
        switch self {
        case .live: "dot.radiowaves.left.and.right"
        case .demo: "wand.and.stars"
        case .paused: "pause.circle.fill"
        case .off: "antenna.radiowaves.left.and.right.slash"
        }
    }

    var tint: AnyShapeStyle {
        switch self {
        case .live: AnyShapeStyle(Color.green)
        case .demo: AnyShapeStyle(Color.orange)
        case .paused, .off: AnyShapeStyle(HierarchicalShapeStyle.secondary)
        }
    }
}

private struct LiveIndicator: View {
    let status: FeedStatus

    var body: some View {
        Label(status.title, systemImage: status.systemImage)
            .labelStyle(.titleAndIcon)
            .font(.caption.weight(.semibold))
            .foregroundStyle(status.tint)
            .symbolEffect(.variableColor.iterative, isActive: status == .live)
            .contentTransition(.symbolEffect(.replace))
            .padding(.horizontal, 8)
    }
}

private struct DashboardBackground: View {
    var body: some View {
        LinearGradient(
            colors: [Color.accentColor.opacity(0.14), Color.purple.opacity(0.06), .clear],
            startPoint: .topLeading,
            endPoint: .center
        )
        .background(Color(.systemGroupedBackground))
        .ignoresSafeArea()
    }
}

#Preview {
    AppStatsDashboardView(model: LiveTrafficModel(seed: 42, source: .demo), internetAccess: InternetAccessController())
}
