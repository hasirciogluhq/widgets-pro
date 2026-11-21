import Darwin
import Foundation

/// System-wide CPU and memory usage via Mach host APIs (works inside the widget sandbox).
public struct SystemSnapshot: Codable, Sendable {
    public var cpu: Double          // 0...1
    public var memUsed: UInt64      // bytes
    public var memTotal: UInt64     // bytes
    public var date: Date
    public var memFraction: Double { memTotal == 0 ? 0 : Double(memUsed) / Double(memTotal) }
}

public final class SystemStats {
    private var lastTicks: (used: UInt64, total: UInt64)?

    public init() {}

    public func snapshot() -> SystemSnapshot {
        SystemSnapshot(cpu: cpuUsage(), memUsed: memoryUsed(), memTotal: ProcessInfo.processInfo.physicalMemory, date: Date())
    }

    private func readTicks() -> (used: UInt64, total: UInt64)? {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.stride / MemoryLayout<integer_t>.stride)
        let kr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard kr == KERN_SUCCESS else { return nil }
        let t = info.cpu_ticks
        let user = UInt64(t.0), sys = UInt64(t.1), idle = UInt64(t.2), nice = UInt64(t.3)
        return (user + sys + nice, user + sys + idle + nice)
    }

    /// CPU usage since the previous call (first call: since boot).
    public func cpuUsage() -> Double {
        guard let now = readTicks() else { return 0 }
        defer { lastTicks = now }
        let prev = lastTicks ?? (0, 0)
        let total = now.total &- prev.total
        return total == 0 ? 0 : Double(now.used &- prev.used) / Double(total)
    }

    public func memoryUsed() -> UInt64 {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)
        let kr = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard kr == KERN_SUCCESS else { return 0 }
        let page = UInt64(vm_kernel_page_size)
        // Same definition as Activity Monitor's "Memory Used": app + wired + compressed.
        let app = UInt64(stats.internal_page_count) &- UInt64(stats.purgeable_count)
        return (app + UInt64(stats.wire_count) + UInt64(stats.compressor_page_count)) * page
    }
}

public extension UInt64 {
    var byteString: String { ByteCountFormatter.string(fromByteCount: Int64(self), countStyle: .memory) }
}
