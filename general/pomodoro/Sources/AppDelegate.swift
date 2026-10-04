import AppKit
import UserNotifications
import OSLog

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, UNUserNotificationCenterDelegate {
    private let countdown = Countdown()
    private let stopwatch = Stopwatch()
    private let logger = Logger(subsystem: "com.hrithik.pomo", category: "MenuBar")
    private var statusItem: NSStatusItem!
    private var refreshTimer: Timer?
    private weak var focusHeader: NSMenuItem?
    private weak var stopwatchHeader: NSMenuItem?
    private weak var timerAction: NSMenuItem?
    private weak var stopwatchAction: NSMenuItem?
    private weak var resetAction: NSMenuItem?
    private var presetItems: [NSMenuItem] = []
    #if POMO_DEVELOPMENT
    private let isSmokeTest = CommandLine.arguments.contains("--smoke-test")
    #endif

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self
        statusItem.menu = menu
        statusItem.button?.setAccessibilityLabel("Pomo")

        let timer = Timer(timeInterval: 0.25, target: self,
                          selector: #selector(refresh), userInfo: nil, repeats: true)
        timer.tolerance = 0.05
        // Common modes include menu tracking: both labels continue updating in an open menu.
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer
        render()
        logger.info("Menu bar ready")

        #if POMO_DEVELOPMENT
        if isSmokeTest { runSmokeTest(); return }
        #endif
        if Bundle.main.bundleIdentifier != nil {
            let center = UNUserNotificationCenter.current()
            center.delegate = self
            center.requestAuthorization(options: [.alert, .sound]) { [logger] _, error in
                if let error { logger.error("Notification authorization: \(error.localizedDescription, privacy: .public)") }
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        refreshTimer?.invalidate()
    }

    @objc private func refresh() {
        if let finished = countdown.tick() { announce(finished) }
        render()
    }

    private func render() {
        guard let button = statusItem.button else { return }
        let title = NSMutableAttributedString(string: "")
        var descriptions: [String] = []
        if let preset = countdown.preset {
            let time = TimeFormat.clock(countdown.remaining, roundUp: true)
            title.append(segment(symbol: preset.isFocus ? "brain.head.profile" : "cup.and.saucer",
                                 text: time, paused: !countdown.isRunning))
            descriptions.append("\(preset.menuTitle), \(time) remaining\(countdown.isRunning ? "" : ", paused")")
        }
        if stopwatch.hasTime {
            if title.length > 0 { title.append(NSAttributedString(string: "   ")) }
            let time = TimeFormat.clock(stopwatch.elapsed)
            title.append(segment(symbol: "stopwatch", text: time, paused: !stopwatch.isRunning))
            descriptions.append("Stopwatch, \(time)\(stopwatch.isRunning ? "" : ", paused")")
        }
        if title.length == 0 { title.append(segment(symbol: "timer", text: "", paused: false)) }
        button.attributedTitle = title
        button.toolTip = descriptions.isEmpty ? "Pomo · click to start a timer" : descriptions.joined(separator: "\n")
        button.setAccessibilityLabel(descriptions.isEmpty ? "Pomo" : descriptions.joined(separator: ". "))

        focusHeader?.title = "Pomo · \(countdown.completedFocusSessions) focus sessions done"
        stopwatchHeader?.title = "Stopwatch · \(TimeFormat.clock(stopwatch.elapsed))"
        timerAction?.title = countdown.isRunning ? "Pause Timer" : "Resume Timer"
        timerAction?.isEnabled = countdown.isActive
        stopwatchAction?.title = stopwatch.isRunning ? "Pause Stopwatch" : (stopwatch.hasTime ? "Resume Stopwatch" : "Start Stopwatch")
        resetAction?.isEnabled = stopwatch.hasTime || stopwatch.isRunning
        for (index, item) in presetItems.enumerated() {
            item.state = countdown.preset == Preset.all[index] ? .on : .off
        }
    }

    private func segment(symbol: String, text: String, paused: Bool) -> NSAttributedString {
        let result = NSMutableAttributedString(string: "")
        let attachment = NSTextAttachment()
        let configuration = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration)
        image?.isTemplate = true
        attachment.image = image
        attachment.bounds = NSRect(x: 0, y: -2, width: 15, height: 15)
        result.append(NSAttributedString(attachment: attachment))
        if !text.isEmpty { result.append(NSAttributedString(string: " " + text)) }
        result.addAttributes([
            .font: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular),
            .foregroundColor: paused ? NSColor.secondaryLabelColor : NSColor.labelColor
        ], range: NSRange(location: 0, length: result.length))
        return result
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        presetItems.removeAll()
        focusHeader = addItem("", to: menu)
        for (index, preset) in Preset.all.enumerated() {
            if index > 0 && Preset.all[index - 1].isFocus != preset.isFocus {
                menu.addItem(.separator())
            }
            let item = addItem(preset.menuTitle, action: #selector(startPreset(_:)), to: menu)
            item.tag = index
            presetItems.append(item)
        }
        timerAction = nil
        if countdown.isActive {
            menu.addItem(.separator())
            timerAction = addItem("", action: #selector(toggleTimer), to: menu)
            addItem("Stop Timer", action: #selector(stopTimer), to: menu)
        }
        menu.addItem(.separator())
        stopwatchHeader = addItem("", to: menu)
        stopwatchAction = addItem("", action: #selector(toggleStopwatch), to: menu)
        resetAction = nil
        if stopwatch.hasTime || stopwatch.isRunning {
            resetAction = addItem("Reset Stopwatch", action: #selector(resetStopwatch), to: menu)
        }
        menu.addItem(.separator())
        let quit = addItem("Quit", action: #selector(NSApplication.terminate(_:)), to: menu)
        quit.target = NSApp
        quit.keyEquivalent = "q"
        render()
    }

    @discardableResult
    private func addItem(_ title: String, action: Selector? = nil, to menu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.isEnabled = action != nil
        menu.addItem(item)
        return item
    }

    @objc private func startPreset(_ item: NSMenuItem) {
        guard Preset.all.indices.contains(item.tag) else { return }
        countdown.start(Preset.all[item.tag])
        logger.info("Started \(Preset.all[item.tag].menuTitle, privacy: .public)")
        render()
    }

    @objc private func toggleTimer() { countdown.togglePause(); render() }
    @objc private func stopTimer() { countdown.stop(); render() }
    @objc private func toggleStopwatch() { stopwatch.toggle(); render() }
    @objc private func resetStopwatch() { stopwatch.reset(); render() }

    private func announce(_ preset: Preset) {
        NSSound(named: "Glass")?.play()
        guard Bundle.main.bundleIdentifier != nil else { return }
        let content = UNMutableNotificationContent()
        content.title = preset.isFocus ? "Focus session done" : "Break's over"
        content.body = preset.isFocus ? "\(preset.minutes) minutes of focus. Take a break." : "Back to it."
        content.sound = .default
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        ) { [logger] error in
            if let error { logger.error("Notification delivery: \(error.localizedDescription, privacy: .public)") }
        }
        logger.info("Completed \(preset.menuTitle, privacy: .public)")
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    #if POMO_DEVELOPMENT
    /// Diagnostics use the real menu and action handlers, without requesting notification permission.
    private func runSmokeTest() {
        countdown.start(Preset.all[1])
        stopwatch.toggle()
        render()
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [self] in
            guard let button = statusItem.button, let menu = statusItem.menu else { exit(1) }
            render()
            let title = button.attributedTitle.string
            let frame = button.window?.frame ?? .zero
            let onScreen = button.window?.occlusionState.contains(.visible) ?? false
            var checks: [(String, Bool)] = []
            func check(_ name: String, _ result: Bool) { checks.append((name, result)) }

            check("status item has screen frame", frame.width > 0 && frame.height > 0)
            check("accessory activation (no Dock icon)", NSApp.activationPolicy() == .accessory)
            check("both live timers visible in title", title.contains("24:") && title.contains("00:0"))
            menuNeedsUpdate(menu)
            check("all six presets in menu", presetItems.map(\.title) == Preset.all.map(\.menuTitle))
            check("selected preset checked", presetItems[1].state == .on)
            let headerBefore = stopwatchHeader?.title

            // Advance a full second through tracking events, as an open NSMenu does.
            let deadline = Date().addingTimeInterval(1.1)
            while Date() < deadline { RunLoop.main.run(mode: .eventTracking, before: deadline) }
            check("open menu header updates", stopwatchHeader?.title != headerBefore)
            toggleTimer()
            check("pause action and label", !countdown.isRunning && timerAction?.title == "Resume Timer")
            toggleTimer()
            check("resume action", countdown.isRunning && timerAction?.title == "Pause Timer")
            stopTimer()
            check("stop clears only countdown", !countdown.isActive && stopwatch.isRunning)
            toggleStopwatch()
            check("stopwatch pause label", stopwatchAction?.title == "Resume Stopwatch")
            resetStopwatch()
            menuNeedsUpdate(menu)
            check("reset returns to icon only", button.attributedTitle.length == 1 && stopwatchAction?.title == "Start Stopwatch")
            check("idle menu hides timer controls", !menu.items.contains { $0.title == "Stop Timer" })

            let report = "frame=\(frame) onScreen=\(onScreen) title=\(title)\n"
                + checks.map { "\($0.1 ? "PASS" : "FAIL"): \($0.0)" }.joined(separator: "\n") + "\n"
            print(report)
            fflush(stdout)
            if let flag = CommandLine.arguments.firstIndex(of: "--diagnostics-path"),
               CommandLine.arguments.indices.contains(flag + 1) {
                try? report.write(toFile: CommandLine.arguments[flag + 1], atomically: true, encoding: .utf8)
            }
            exit(checks.allSatisfy(\.1) ? 0 : 1)
        }
    }
    #endif
}
