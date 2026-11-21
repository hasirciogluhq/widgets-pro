import Darwin
import Foundation

/// One process, with its children (parent / sub-process tree built from ppid).
public struct ProcessNode: Identifiable, Sendable {
    public let id: pid_t
    public let ppid: pid_t
    public let name: String
    public var cpu: Double            // fraction of one core since last sample
    public var memory: UInt64         // resident bytes (phys footprint)
    public var children: [ProcessNode] = []

    /// Totals including all descendants.
    public var totalCPU: Double { cpu + children.reduce(0) { $0 + $1.totalCPU } }
    public var totalMemory: UInt64 { memory + children.reduce(0) { $0 + $1.totalMemory } }
    public var childrenOrNil: [ProcessNode]? { children.isEmpty ? nil : children }
}

/// Samples all processes via libproc. Needs a non-sandboxed process (the menu bar app).
public final class ProcessSampler {
    private var lastCPU: [pid_t: UInt64] = [:]   // ns of cpu time
    private var lastDate = Date()
    private let timebase: Double = {
        var tb = mach_timebase_info_data_t(); mach_timebase_info(&tb)
        return Double(tb.numer) / Double(tb.denom)
    }()

    public init() {}

    public func sample() -> [ProcessNode] {
        let n = proc_listallpids(nil, 0)
        guard n > 0 else { return [] }
        var pids = [pid_t](repeating: 0, count: Int(n) * 2)
        let got = proc_listallpids(&pids, Int32(pids.count * MemoryLayout<pid_t>.size))
        let now = Date()
        let elapsed = max(now.timeIntervalSince(lastDate), 0.001) * 1e9
        var flat: [ProcessNode] = []
        var nextCPU: [pid_t: UInt64] = [:]

        for pid in pids.prefix(Int(got)) where pid > 0 {
            var bsd = proc_bsdinfo()
            guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &bsd, Int32(MemoryLayout<proc_bsdinfo>.size)) > 0 else { continue }
            var usage = rusage_info_v4()
            let ok = withUnsafeMutablePointer(to: &usage) {
                $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { proc_pid_rusage(pid, RUSAGE_INFO_V4, $0) }
            } == 0
            let cpuNs = ok ? UInt64(Double(usage.ri_user_time + usage.ri_system_time) * timebase) : 0
            nextCPU[pid] = cpuNs
            let delta = lastCPU[pid].map { cpuNs > $0 ? Double(cpuNs - $0) : 0 } ?? 0
            flat.append(ProcessNode(id: pid, ppid: pid_t(bsd.pbi_ppid), name: Self.name(of: pid, bsd: bsd),
                                    cpu: delta / elapsed, memory: ok ? usage.ri_phys_footprint : 0))
        }
        lastCPU = nextCPU
        lastDate = now
        return flat
    }

    /// Builds the parent/child tree. Roots are processes whose parent is unknown or launchd (pid 1).
    public static func tree(from flat: [ProcessNode], rootsUnderLaunchd: Bool = true) -> [ProcessNode] {
        let byParent = Dictionary(grouping: flat, by: \.ppid)
        let known = Set(flat.map(\.id))
        func build(_ p: ProcessNode, depth: Int) -> ProcessNode {
            var p = p
            if depth < 64 { p.children = (byParent[p.id] ?? []).filter { $0.id != p.id }.map { build($0, depth: depth + 1) }
                .sorted { $0.totalCPU > $1.totalCPU } }
            return p
        }
        let roots = flat.filter { p in
            rootsUnderLaunchd ? (p.ppid == 1 || !known.contains(p.ppid)) && p.id != 1 : !known.contains(p.ppid)
        }
        return roots.map { build($0, depth: 0) }.sorted { $0.totalCPU > $1.totalCPU }
    }

    private static func name(of pid: pid_t, bsd: proc_bsdinfo) -> String {
        var buf = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        if proc_pidpath(pid, &buf, UInt32(buf.count)) > 0 {
            let path = String(cString: buf)
            if let r = path.range(of: ".app/") { return URL(fileURLWithPath: String(path[..<r.lowerBound])).lastPathComponent }
            return URL(fileURLWithPath: path).lastPathComponent
        }
        var comm = bsd.pbi_name
        return withUnsafePointer(to: &comm) { String(cString: UnsafeRawPointer($0).assumingMemoryBound(to: CChar.self)) }
    }
}
