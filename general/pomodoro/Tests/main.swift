import Foundation

var passed = 0
var failed = 0

func expect(_ condition: @autoclosure () -> Bool, _ message: String, line: Int = #line) {
    if condition() { passed += 1 }
    else {
        failed += 1
        print("FAIL (line \(line)): \(message)")
    }
}

func test(_ name: String, _ body: () -> Void) {
    print("· \(name)")
    body()
}

final class FakeClock {
    var now = Date(timeIntervalSince1970: 1_000_000)
    func advance(_ seconds: TimeInterval) { now.addTimeInterval(seconds) }
}

test("Time formatting and rounding boundaries") {
    expect(TimeFormat.clock(0) == "00:00", "zero")
    expect(TimeFormat.clock(59.9) == "00:59", "stopwatch rounds down")
    expect(TimeFormat.clock(59.1, roundUp: true) == "01:00", "countdown rounds up")
    expect(TimeFormat.clock(1500, roundUp: true) == "25:00", "initial countdown")
    expect(TimeFormat.clock(3661) == "1:01:01", "hours")
    expect(TimeFormat.clock(-5) == "00:00", "negative values clamp to zero")
}

test("Six presets") {
    expect(Preset.all.filter(\.isFocus).map(\.minutes) == [15, 25, 45, 60], "focus order")
    expect(Preset.all.filter { !$0.isFocus }.map(\.minutes) == [5, 15], "break durations")
    expect(Preset.all[1].menuTitle == "Focus · 25 min", "menu title")
}

test("Countdown pause, resume, and exactly-once completion") {
    let clock = FakeClock()
    let timer = Countdown(clock: { clock.now })
    expect(!timer.isActive && timer.remaining == 0, "initially idle")
    timer.start(Preset.all[1])
    expect(timer.isRunning && timer.remaining == 1500, "start 25 minutes")
    clock.advance(600)
    expect(timer.remaining == 900, "ten minutes elapsed")
    timer.togglePause()
    clock.advance(10_000)
    expect(!timer.isRunning && timer.remaining == 900 && timer.tick() == nil, "paused time excluded")
    timer.togglePause()
    clock.advance(899)
    expect(timer.remaining == 1 && timer.tick() == nil, "no early completion")
    clock.advance(1)
    expect(timer.tick() == Preset.all[1], "completion returns preset")
    expect(timer.tick() == nil, "no duplicate completion")
    expect(!timer.isActive && !timer.isRunning && timer.remaining == 0, "completion clears timer")
    expect(timer.completedFocusSessions == 1, "focus counted exactly once")
}

test("Breaks, selecting the same preset, and stopping") {
    let clock = FakeClock()
    let timer = Countdown(clock: { clock.now })
    timer.start(Preset.all[4])
    clock.advance(300)
    expect(timer.tick() == Preset.all[4] && timer.completedFocusSessions == 0, "break not counted")
    timer.start(Preset.all[0])
    clock.advance(100)
    expect(timer.remaining == 800, "first run progresses")
    timer.start(Preset.all[0])
    expect(timer.remaining == 900, "same preset restarts")
    timer.stop()
    expect(!timer.isActive && !timer.isRunning && timer.remaining == 0, "stop clears timer")
    timer.togglePause()
    expect(!timer.isRunning && timer.tick() == nil, "pause while idle is a no-op")
}

test("Independent stopwatch") {
    let clock = FakeClock()
    let stopwatch = Stopwatch(clock: { clock.now })
    stopwatch.toggle()
    clock.advance(65)
    expect(stopwatch.isRunning && stopwatch.hasTime && stopwatch.elapsed == 65, "runs")
    stopwatch.toggle()
    clock.advance(1000)
    expect(!stopwatch.isRunning && stopwatch.elapsed == 65, "pause excludes elapsed wall time")
    stopwatch.toggle()
    clock.advance(5)
    expect(stopwatch.elapsed == 70, "resume preserves accumulated time")
    stopwatch.reset()
    expect(!stopwatch.isRunning && !stopwatch.hasTime && stopwatch.elapsed == 0, "reset stops and clears")
    stopwatch.reset()
    expect(stopwatch.elapsed == 0, "reset is idempotent")
}

test("Sleep, timer independence, and preserving session count") {
    let clock = FakeClock()
    let timer = Countdown(clock: { clock.now })
    let stopwatch = Stopwatch(clock: { clock.now })
    timer.start(Preset.all[0])
    stopwatch.toggle()
    clock.advance(3600) // No refreshes while the computer is asleep.
    expect(timer.remaining == 0 && timer.tick() == Preset.all[0], "late refresh completes after sleep")
    expect(stopwatch.elapsed == 3600 && stopwatch.isRunning, "countdown completion leaves stopwatch running")
    timer.start(Preset.all[4])
    timer.stop()
    expect(timer.completedFocusSessions == 1, "stop preserves completed sessions")
    stopwatch.reset()
    timer.start(Preset.all[1])
    stopwatch.toggle()
    clock.advance(0.1)
    expect(TimeFormat.clock(timer.remaining, roundUp: true) == "25:00", "no immediate countdown flicker")
    timer.togglePause()
    clock.advance(10)
    expect(abs(stopwatch.elapsed - 10.1) < 0.001, "pausing countdown leaves stopwatch running")
}

if failed == 0 {
    print("All \(passed) checks passed.")
    exit(0)
}
print("\(failed) failed, \(passed) passed.")
exit(1)
