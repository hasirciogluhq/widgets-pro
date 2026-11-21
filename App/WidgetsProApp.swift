import SwiftUI
import WidgetKit

@main
struct WidgetsProApp: App {
    @StateObject private var monitor = Monitor()

    var body: some Scene {
        MenuBarExtra {
            MenuView().environmentObject(monitor)
        } label: {
            Label("\(Int(monitor.system.cpu * 100))%", systemImage: "cpu")
                .labelStyle(.titleAndIcon)
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
final class Monitor: ObservableObject {
    struct Point: Identifiable { let id = UUID(); let date: Date; let cpu: Double; let mem: Double }

    @Published var system = SystemSnapshot(cpu: 0, memUsed: 0, memTotal: 0, date: .now)
    @Published var history: [Point] = []
    @Published var tree: [ProcessNode] = []
    @Published var topApps: [ProcessNode] = []
    @Published var tab = 0

    private let stats = SystemStats()
    private let sampler = ProcessSampler()
    private var timer: Timer?
    private var ticks = 0

    init() {
        _ = sampler.sample()
        tick()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    private func tick() {
        system = stats.snapshot()
        history.append(.init(date: system.date, cpu: system.cpu, mem: system.memFraction))
        if history.count > 60 { history.removeFirst(history.count - 60) }
        tree = ProcessSampler.tree(from: sampler.sample())
        topApps = Array(tree.sorted { $0.totalCPU > $1.totalCPU }.prefix(8))
        SharedStore.save(system)
        ticks += 1
        if ticks % 15 == 0 { WidgetCenter.shared.reloadAllTimelines() }   // ~30s
    }
}
