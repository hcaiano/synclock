import Foundation

/// Monotonic host clock in nanoseconds, in the same time domain CoreMIDI uses
/// for packet timestamps (mach uptime). NEVER use `Date`/`DispatchTime` in
/// timing code — only this and Link `clock().micros()`.
public enum HostTime {
    /// Current host time in nanoseconds (CLOCK_UPTIME_RAW == mach_absolute_time
    /// expressed in ns; monotonic, excludes sleep, overflow-safe).
    @inline(__always)
    public static func nowNanos() -> UInt64 {
        clock_gettime_nsec_np(CLOCK_UPTIME_RAW)
    }
}
