import SwiftUI
import WidgetKit

struct StatsEntry: TimelineEntry {
    let date: Date
    let snapshot: SystemSnapshot
}

struct StatsProvider: TimelineProvider {
    func placeholder(in context: Context) -> StatsEntry {
        StatsEntry(date: .now, snapshot: .init(cpu: 0.23, memUsed: 8 << 30, memTotal: 16 << 30, date: .now))
    }
    func getSnapshot(in context: Context, completion: @escaping (StatsEntry) -> Void) { completion(current()) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<StatsEntry>) -> Void) {
        completion(Timeline(entries: [current()], policy: .after(.now.addingTimeInterval(60))))
    }
    private func current() -> StatsEntry {
        // Mach host stats work inside the sandbox; fall back to the app's last value.
        let s = SystemStats()
        _ = s.cpuUsage()
        usleep(200_000)
        var snap = s.snapshot()
        if snap.memTotal == 0, let saved = SharedStore.load() { snap = saved }
        return StatsEntry(date: .now, snapshot: snap)
    }
}

struct StatsWidgetView: View {
    let entry: StatsEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("System", systemImage: "cpu").font(.headline)
            Ring(title: "CPU", value: entry.snapshot.cpu, color: .blue)
            Ring(title: "MEM", value: entry.snapshot.memFraction, color: .green)
            Text(entry.snapshot.memUsed.byteString).font(.caption2).foregroundStyle(.secondary)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

private struct Ring: View {
    let title: String, value: Double, color: Color
    var body: some View {
        HStack {
            Text(title).font(.caption.bold()).frame(width: 34, alignment: .leading)
            ProgressView(value: min(max(value, 0), 1)).tint(color)
            Text("\(Int(value * 100))%").font(.caption.monospacedDigit())
        }
    }
}

struct StatsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "StatsWidget", provider: StatsProvider()) { StatsWidgetView(entry: $0) }
            .configurationDisplayName("CPU & Memory")
            .description("System CPU and memory usage.")
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct WidgetsProWidgetBundle: WidgetBundle {
    var body: some Widget { StatsWidget() }
}
