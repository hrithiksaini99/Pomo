import Foundation

typealias Clock = () -> Date

/// Shared elapsed-time arithmetic. Dates, rather than tick counts, include time asleep.
struct ElapsedCounter {
    private(set) var accumulated: TimeInterval = 0
    private(set) var startedAt: Date?

    var isRunning: Bool { startedAt != nil }

    func elapsed(at now: Date) -> TimeInterval {
        accumulated + (startedAt.map { max(0, now.timeIntervalSince($0)) } ?? 0)
    }

    mutating func start(at now: Date) {
        guard !isRunning else { return }
        startedAt = now
    }

    mutating func pause(at now: Date) {
        guard isRunning else { return }
        accumulated = elapsed(at: now)
        startedAt = nil
    }

    mutating func reset() {
        accumulated = 0
        startedAt = nil
    }
}

struct Preset: Equatable {
    let title: String
    let minutes: Int
    let isFocus: Bool

    var duration: TimeInterval { TimeInterval(minutes * 60) }
    var menuTitle: String { "\(title) · \(minutes) min" }

    static let all: [Preset] = [
        Preset(title: "Focus", minutes: 15, isFocus: true),
        Preset(title: "Focus", minutes: 25, isFocus: true),
        Preset(title: "Focus", minutes: 45, isFocus: true),
        Preset(title: "Focus", minutes: 60, isFocus: true),
        Preset(title: "Short Break", minutes: 5, isFocus: false),
        Preset(title: "Long Break", minutes: 15, isFocus: false)
    ]
}

final class Countdown {
    private let clock: Clock
    private var counter = ElapsedCounter()
    private(set) var preset: Preset?
    private(set) var completedFocusSessions = 0

    init(clock: @escaping Clock = Date.init) { self.clock = clock }

    var isActive: Bool { preset != nil }
    var isRunning: Bool { counter.isRunning }
    var remaining: TimeInterval {
        guard let preset else { return 0 }
        return max(0, preset.duration - counter.elapsed(at: clock()))
    }

    /// Selecting any preset starts it afresh, including the current preset.
    func start(_ preset: Preset) {
        self.preset = preset
        counter.reset()
        counter.start(at: clock())
    }

    func togglePause() {
        guard isActive else { return }
        if isRunning { counter.pause(at: clock()) }
        else { counter.start(at: clock()) }
    }

    func stop() {
        preset = nil
        counter.reset()
    }

    /// Called every refresh; returns a completed session exactly once.
    @discardableResult
    func tick() -> Preset? {
        guard let preset, isRunning, remaining <= 0 else { return nil }
        if preset.isFocus { completedFocusSessions += 1 }
        stop()
        return preset
    }
}

final class Stopwatch {
    private let clock: Clock
    private var counter = ElapsedCounter()

    init(clock: @escaping Clock = Date.init) { self.clock = clock }

    var isRunning: Bool { counter.isRunning }
    var elapsed: TimeInterval { counter.elapsed(at: clock()) }
    var hasTime: Bool { elapsed > 0 }

    func toggle() {
        if isRunning { counter.pause(at: clock()) }
        else { counter.start(at: clock()) }
    }

    func reset() { counter.reset() }
}

enum TimeFormat {
    static func clock(_ time: TimeInterval, roundUp: Bool = false) -> String {
        let seconds = Int(max(0, time).rounded(roundUp ? .up : .down))
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remainder = seconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, remainder)
        }
        return String(format: "%02d:%02d", minutes, remainder)
    }
}
