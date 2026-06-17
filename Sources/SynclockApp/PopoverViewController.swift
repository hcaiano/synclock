import AppKit
import SynclockCore
import SynclockMIDI

/// The menubar popover — primary surface (site/hero-popover.html spec). Editable
/// BPM + nudge/scroll, flat mint Play + Tap transport, the bar-phase indicator,
/// an Ableton Link on/off toggle + peer count, output health, and the footer.
/// Reads `SyncEngine.snapshot()` + `currentBarPhase()`; calls engine methods only.
final class PopoverViewController: NSViewController, NSTextFieldDelegate {
    private let engine: SyncEngine
    var openPreferences: (() -> Void)?

    private let bpmField = TempoField(labelWithString: "120")
    private let beatBar = BeatPhaseView(frame: .zero)
    private let linkToggle = MintToggle(frame: .zero)
    private let linkTitle = NSTextField(labelWithString: "Ableton Link")
    private let peersLabel = NSTextField(labelWithString: "")
    private let hintLabel = NSTextField(labelWithString: "")
    private let playButton: FlatButton
    private let tapButton: FlatButton
    private let nudgeUpButton: FlatButton
    private let nudgeDownButton: FlatButton
    private let healthLabel = NSTextField(labelWithString: "")
    private let pulse = PulseView()
    private var tap = TapTempo()
    private var refreshTimer: Timer?
    private var lastSnapshot: SyncEngine.Snapshot?
    private var committingBPM = false

    private var contentWidth: CGFloat { Theme.popoverWidth - 32 }

    init(engine: SyncEngine) {
        self.engine = engine
        self.playButton = FlatButton(title: "Play",
                                     font: .systemFont(ofSize: 14, weight: .semibold),
                                     target: nil, action: nil)
        self.tapButton = FlatButton(title: "Tap",
                                    font: .systemFont(ofSize: 13, weight: .medium),
                                    target: nil, action: nil)
        self.nudgeUpButton = FlatButton(title: "▲",
                                        font: .systemFont(ofSize: 10),
                                        target: nil, action: nil)
        self.nudgeDownButton = FlatButton(title: "▼",
                                          font: .systemFont(ofSize: 10),
                                          target: nil, action: nil)
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        let effect = NSVisualEffectView()
        effect.material = .popover
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.appearance = NSAppearance(named: .vibrantDark)
        effect.translatesAutoresizingMaskIntoConstraints = false
        effect.widthAnchor.constraint(equalToConstant: Theme.popoverWidth).isActive = true

        let stack = NSStackView(views: [
            tempoRow(), beatBarRow(), transportRow(),
            separator(), linkSection(),
            separator(), healthRow(),
            separator(), footerRow(),
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 12, right: 16)
        stack.setCustomSpacing(10, after: stack.arrangedSubviews[0])  // tempo → beat bar
        stack.setCustomSpacing(14, after: stack.arrangedSubviews[1])  // beat bar → transport
        stack.translatesAutoresizingMaskIntoConstraints = false
        effect.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: effect.topAnchor),
            stack.bottomAnchor.constraint(equalTo: effect.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: effect.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: effect.trailingAnchor),
        ])
        view = effect
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        refresh()
        beatBar.phaseProvider = { [weak self] in
            guard let self else { return (0, 0, false) }
            let snap = self.lastSnapshot
            let running = (snap?.transport == .playing)
                || (snap?.linkEnabled == true && (snap?.peerCount ?? 0) > 0)
            return (self.engine.currentBarPhase(), self.engine.currentBeatInBar(), running)
        }
        beatBar.setActive(true)
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }
    override func viewDidDisappear() {
        super.viewDidDisappear()
        refreshTimer?.invalidate(); refreshTimer = nil
        beatBar.setActive(false)
    }

    // MARK: - Sections

    private func tempoRow() -> NSView {
        bpmField.isEditable = true
        bpmField.isSelectable = true
        bpmField.isBordered = false
        bpmField.drawsBackground = false
        bpmField.focusRingType = .none
        bpmField.font = Theme.monoDigits(size: 40, weight: .medium)
        bpmField.textColor = Theme.ink
        bpmField.alignment = .left
        bpmField.delegate = self
        bpmField.target = self
        bpmField.action = #selector(bpmCommitted)
        bpmField.cell?.wraps = false
        bpmField.cell?.isScrollable = true
        bpmField.setContentHuggingPriority(.required, for: .horizontal)
        bpmField.setContentCompressionResistancePriority(.required, for: .horizontal)
        bpmField.setAccessibilityLabel("Tempo in beats per minute, editable")
        bpmField.onScrollStep = { [weak self] dir in self?.scrollTempo(dir) }

        let unit = NSTextField(labelWithString: "BPM")
        unit.font = .systemFont(ofSize: 11, weight: .semibold)
        unit.textColor = Theme.inkMuted
        let bpmStack = NSStackView(views: [bpmField, unit])
        bpmStack.alignment = .firstBaseline
        bpmStack.spacing = 6

        configureNudgeButton(nudgeUpButton, title: "▲", action: #selector(nudgeUp))
        configureNudgeButton(nudgeDownButton, title: "▼", action: #selector(nudgeDown))
        let nudges = NSStackView(views: [nudgeUpButton, nudgeDownButton])
        nudges.orientation = .vertical
        nudges.spacing = 4

        let row = NSStackView(views: [bpmStack, NSView(), nudges])
        row.alignment = .centerY
        row.widthAnchor.constraint(equalToConstant: contentWidth).isActive = true
        return row
    }

    private func beatBarRow() -> NSView {
        beatBar.translatesAutoresizingMaskIntoConstraints = false
        beatBar.widthAnchor.constraint(equalToConstant: contentWidth).isActive = true
        beatBar.heightAnchor.constraint(equalToConstant: 6).isActive = true
        return beatBar
    }

    private func transportRow() -> NSView {
        playButton.fillColor = Theme.accent
        playButton.pressedFillColor = Theme.accent.blended(withFraction: 0.16, of: .black)
        playButton.titleColor = Theme.inkOnAccent
        playButton.cornerRadius = 11
        playButton.target = self
        playButton.action = #selector(toggleTransport)
        playButton.heightAnchor.constraint(equalToConstant: 40).isActive = true
        playButton.setContentHuggingPriority(.defaultLow, for: .horizontal)

        tapButton.target = self
        tapButton.action = #selector(tapTempo)
        tapButton.fillColor = Theme.surface
        tapButton.titleColor = Theme.inkSecondary
        tapButton.borderColor = Theme.hairline
        tapButton.cornerRadius = 11
        tapButton.heightAnchor.constraint(equalToConstant: 40).isActive = true
        tapButton.widthAnchor.constraint(equalToConstant: 66).isActive = true
        tapButton.setContentHuggingPriority(.required, for: .horizontal)
        tapButton.setAccessibilityLabel("Tap tempo")

        let row = NSStackView(views: [playButton, tapButton])
        row.distribution = .fill
        row.spacing = 10
        row.widthAnchor.constraint(equalToConstant: contentWidth).isActive = true
        return row
    }

    private func linkSection() -> NSView {
        linkTitle.font = .systemFont(ofSize: 13, weight: .medium)
        linkTitle.textColor = Theme.ink
        peersLabel.font = .systemFont(ofSize: 11)
        peersLabel.textColor = Theme.inkSecondary

        linkToggle.target = self
        linkToggle.action = #selector(linkToggled)
        linkToggle.setAccessibilityLabel("Ableton Link")

        let titleRow = NSStackView(views: [linkTitle, NSView(), peersLabel, linkToggle])
        titleRow.alignment = .centerY
        titleRow.spacing = 8
        titleRow.widthAnchor.constraint(equalToConstant: contentWidth).isActive = true

        hintLabel.font = .systemFont(ofSize: 11)
        hintLabel.textColor = Theme.inkMuted
        hintLabel.lineBreakMode = .byWordWrapping
        hintLabel.maximumNumberOfLines = 2
        hintLabel.preferredMaxLayoutWidth = contentWidth

        let col = NSStackView(views: [titleRow, hintLabel])
        col.orientation = .vertical
        col.alignment = .leading
        col.spacing = 5
        return col
    }

    private func healthRow() -> NSView {
        pulse.widthAnchor.constraint(equalToConstant: 10).isActive = true
        pulse.heightAnchor.constraint(equalToConstant: 10).isActive = true
        healthLabel.font = .systemFont(ofSize: 12.5)
        healthLabel.textColor = Theme.ink
        let button = NSButton(title: "Devices ›", target: self, action: #selector(openPrefs))
        button.isBordered = false
        button.contentTintColor = Theme.inkMuted
        let row = NSStackView(views: [pulse, healthLabel, NSView(), button])
        row.alignment = .centerY
        row.widthAnchor.constraint(equalToConstant: contentWidth).isActive = true
        return row
    }

    private func footerRow() -> NSView {
        let prefs = NSButton(title: "Preferences…", target: self, action: #selector(openPrefs))
        prefs.isBordered = false
        prefs.contentTintColor = Theme.inkMuted
        let quit = NSButton(title: "Quit", target: NSApp, action: #selector(NSApplication.terminate(_:)))
        quit.isBordered = false
        quit.contentTintColor = Theme.inkMuted
        let row = NSStackView(views: [prefs, NSView(), quit])
        row.alignment = .centerY
        row.widthAnchor.constraint(equalToConstant: contentWidth).isActive = true
        return row
    }

    // MARK: - Helpers

    private func configureNudgeButton(_ b: FlatButton, title: String, action: Selector) {
        b.target = self
        b.action = action
        b.fillColor = Theme.surface
        b.titleColor = Theme.inkSecondary
        b.borderColor = Theme.hairline
        b.cornerRadius = 7
        b.widthAnchor.constraint(equalToConstant: 30).isActive = true
        b.heightAnchor.constraint(equalToConstant: 22).isActive = true
        b.setAccessibilityLabel(title == "▲" ? "Increase tempo" : "Decrease tempo")
    }

    private func separator() -> NSView {
        let v = NSBox()
        v.boxType = .separator
        v.widthAnchor.constraint(equalToConstant: contentWidth).isActive = true
        return v
    }

    // MARK: - State

    private func refresh() {
        let snap = engine.snapshot()
        lastSnapshot = snap
        if !bpmField.isEditing { bpmField.stringValue = snap.tempo.description }
        linkToggle.isOn = snap.linkEnabled
        let peerWord = snap.peerCount == 1 ? "peer" : "peers"
        peersLabel.stringValue = snap.linkEnabled
            ? (snap.linkIsReal ? "\(snap.peerCount) \(peerWord)" : "unavailable")
            : ""
        hintLabel.stringValue = hint(linkEnabled: snap.linkEnabled)
        playButton.title = snap.transport == .playing ? "Stop" : "Play"
        healthLabel.stringValue = "\(snap.activeOutputs) active · \(snap.missingOutputs) missing"
        pulse.setBeating(snap.transport == .playing, bpm: snap.tempo.bpm)
        view.window?.setAccessibilityLabel(
            "Synclock, \(snap.transport == .playing ? "playing" : "stopped"), \(snap.tempo) BPM, Link \(snap.linkEnabled ? "on" : "off")")
    }

    private func hint(linkEnabled: Bool) -> String {
        linkEnabled
            ? "On — tempo and start/stop stay in sync with every Link app and device on the network."
            : "Off — Synclock runs its own clock."
    }

    // MARK: - Actions

    @objc private func toggleTransport() { engine.toggle(); refresh() }
    @objc private func nudgeUp() { engine.setTempo(engine.snapshot().tempo.nudged(by: 0.1)); refresh() }
    @objc private func nudgeDown() { engine.setTempo(engine.snapshot().tempo.nudged(by: -0.1)); refresh() }
    private func scrollTempo(_ dir: Int) {
        engine.setTempo(engine.snapshot().tempo.nudged(by: Double(dir))); refresh()
    }
    @objc private func tapTempo() {
        if let t = tap.tap(at: HostTime.nowNanos()) { engine.setTempo(t); refresh() }
    }
    @objc private func bpmCommitted() { commitBPM() }
    func controlTextDidEndEditing(_ obj: Notification) { commitBPM() }
    private func commitBPM() {
        guard !committingBPM else { return }
        committingBPM = true; defer { committingBPM = false }
        let raw = bpmField.stringValue.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ",", with: ".")
        if let v = Double(raw) { engine.setTempo(Tempo(v)) }
        view.window?.makeFirstResponder(nil)
        refresh()
    }
    @objc private func linkToggled() { engine.setLinkEnabled(linkToggle.isOn); refresh() }
    @objc private func openPrefs() { openPreferences?() }
}

enum PopoverControlSelfTestError: Error, CustomStringConvertible {
    case failed(String)

    var description: String {
        switch self {
        case .failed(let message): return message
        }
    }
}

extension PopoverViewController {
    /// Hidden regression harness for the menubar popover's custom controls.
    /// Exercises the same target/action path as user clicks without requiring
    /// fragile external automation of NSStatusItem popovers.
    func runControlSelfTest() throws -> [String] {
        _ = view
        view.layoutSubtreeIfNeeded()
        viewWillAppear()
        defer { viewDidDisappear() }

        var checks: [String] = []

        func spin(_ seconds: TimeInterval = 0.03) {
            RunLoop.current.run(until: Date().addingTimeInterval(seconds))
        }

        func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
            if !condition() { throw PopoverControlSelfTestError.failed(message) }
            checks.append(message)
        }

        func setBPMText(_ text: String) {
            bpmField.stringValue = text
            _ = bpmField.sendAction(bpmField.action, to: bpmField.target)
            spin()
        }

        setBPMText("120")
        nudgeUpButton.performClick(nil); spin()
        try require(abs(engine.snapshot().tempo.bpm - 120.1) < 0.06, "nudge up changes BPM by +0.1")
        nudgeDownButton.performClick(nil); spin()
        try require(abs(engine.snapshot().tempo.bpm - 120.0) < 0.06, "nudge down changes BPM by -0.1")

        setBPMText("333")
        try require(abs(engine.snapshot().tempo.bpm - 300.0) < 0.01, "typed BPM clamps high to 300")
        setBPMText("25")
        try require(abs(engine.snapshot().tempo.bpm - 30.0) < 0.01, "typed BPM clamps low to 30")
        setBPMText("137.5")
        try require(abs(engine.snapshot().tempo.bpm - 137.5) < 0.01, "typed BPM commits decimal value")

        bpmField.scrollWheel(with: syntheticScroll(deltaY: 6)); spin()
        try require(abs(engine.snapshot().tempo.bpm - 138.5) < 0.01, "tempo scroll nudges +1 BPM")
        bpmField.scrollWheel(with: syntheticScroll(deltaY: -6)); spin()
        try require(abs(engine.snapshot().tempo.bpm - 137.5) < 0.01, "tempo scroll nudges -1 BPM")

        let beforeTap = engine.snapshot().tempo.bpm
        for _ in 0..<4 {
            tapButton.performClick(nil)
            Thread.sleep(forTimeInterval: 0.25)
            spin(0.01)
        }
        let afterTap = engine.snapshot().tempo.bpm
        try require(afterTap > beforeTap + 30 && afterTap <= 300, "tap button updates BPM from rhythmic clicks")

        if engine.snapshot().transport == .playing { playButton.performClick(nil); spin() }
        playButton.performClick(nil); spin()
        try require(engine.snapshot().transport == .playing, "play button starts transport")
        let phaseA = engine.currentBarPhase()
        Thread.sleep(forTimeInterval: 0.12); spin()
        let phaseB = engine.currentBarPhase()
        try require(abs(phaseB - phaseA) > 0.0001, "beat bar phase advances while playing")
        playButton.performClick(nil); spin()
        try require(engine.snapshot().transport == .stopped, "stop button stops transport")

        if engine.snapshot().linkEnabled {
            linkToggle.mouseDown(with: syntheticMouseDown())
            spin()
        }
        linkToggle.mouseDown(with: syntheticMouseDown()); spin()
        try require(engine.snapshot().linkEnabled, "Link toggle turns on")
        linkToggle.mouseDown(with: syntheticMouseDown()); spin()
        try require(!engine.snapshot().linkEnabled, "Link toggle turns off")

        return checks
    }

    private func syntheticMouseDown() -> NSEvent {
        NSEvent.mouseEvent(with: .leftMouseDown,
                           location: .zero,
                           modifierFlags: [],
                           timestamp: ProcessInfo.processInfo.systemUptime,
                           windowNumber: 0,
                           context: nil,
                           eventNumber: 0,
                           clickCount: 1,
                           pressure: 1) ?? NSEvent()
    }

    private func syntheticScroll(deltaY: Int32) -> NSEvent {
        let cg = CGEvent(scrollWheelEvent2Source: nil,
                         units: .pixel,
                         wheelCount: 1,
                         wheel1: deltaY,
                         wheel2: 0,
                         wheel3: 0)
        return cg.flatMap { NSEvent(cgEvent: $0) } ?? NSEvent()
    }
}
