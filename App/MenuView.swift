import Charts
import SwiftUI

struct MenuView: View {
    @EnvironmentObject var monitor: Monitor

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Gauge(title: "CPU", value: monitor.system.cpu, detail: "\(Int(monitor.system.cpu * 100))%")
                Gauge(title: "Memory", value: monitor.system.memFraction,
                      detail: "\(monitor.system.memUsed.byteString) / \(monitor.system.memTotal.byteString)")
            }
            Chart(monitor.history) {
                LineMark(x: .value("t", $0.date), y: .value("CPU", $0.cpu), series: .value("s", "CPU"))
                    .foregroundStyle(.blue)
                LineMark(x: .value("t", $0.date), y: .value("Mem", $0.mem), series: .value("s", "Memory"))
                    .foregroundStyle(.green)
            }
            .chartYScale(domain: 0...1)
            .chartXAxis(.hidden)
            .frame(height: 70)

            Picker("", selection: $monitor.tab) {
                Text("Top apps").tag(0)
                Text("Process tree").tag(1)
            }.pickerStyle(.segmented).labelsHidden()

            if monitor.tab == 0 { TopAppsView(apps: monitor.topApps) } else { ProcessTreeView(tree: monitor.tree) }

            HStack {
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }.keyboardShortcut("q")
            }
        }
        .padding(12)
        .frame(width: 380)
    }
}

private struct Gauge: View {
    let title: String, value: Double, detail: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            ProgressView(value: min(max(value, 0), 1))
            Text(detail).font(.caption.monospacedDigit())
        }.frame(maxWidth: .infinity)
    }
}

struct TopAppsView: View {
    let apps: [ProcessNode]
    var body: some View {
        Chart(apps) { app in
            BarMark(x: .value("CPU %", app.totalCPU * 100), y: .value("App", "\(app.name) (\(app.id))"))
                .annotation(position: .trailing) { Text(String(format: "%.1f%%", app.totalCPU * 100)).font(.caption2) }
        }
        .chartXAxisLabel("CPU % (incl. sub-processes)")
        .frame(height: 220)
    }
}

struct ProcessTreeView: View {
    let tree: [ProcessNode]
    var body: some View {
        List(tree, children: \.childrenOrNil) { p in
            HStack {
                Text(p.name).lineLimit(1)
                Text("\(p.id)").font(.caption2).foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "%.1f%%", p.totalCPU * 100)).monospacedDigit()
                Text(p.totalMemory.byteString).monospacedDigit().frame(width: 70, alignment: .trailing)
            }.font(.caption)
        }
        .frame(height: 260)
    }
}
