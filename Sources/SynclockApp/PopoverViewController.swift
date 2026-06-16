import AppKit
import SynclockCore
import SynclockMIDI

/// The menubar popover — primary surface (design/synclock-mockup.html). BPM,
/// nudge, transport, tap, Link segmented mode + peers, output health, pulse.
/// Reads SyncEngine.snapshot() and calls existing engine methods only.
final class PopoverViewController: NSViewController {
    private let engine: SyncEngine
    private weak var onOpenPreferences: AnyObject?
    var openPreferences: (() -> Void)?

    private let bpmLabel = NSTextField(labelWithString: "120")
    private let modeControl = NSSegmentedControl(labels: LinkMode.allCases.map(\.label),
                                                 trackingMode: .selectOne, target: nil, action: nil)
    private let peersLabel = NSTextField(labelWithString: "")
    private let modeHint = NSTextField(labelWithString: "")
    private let playButton = NSButton()
    private let healthLabel = NSTextField(labelWithString: "")
    private let pulse = PulseView()
    private var tap = TapTempo()
    private var refreshTimer: Timer?

    init(engine: SyncEngine) {
        self.engine = engine
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
            tempoRow(), transportRow(),
            separator(), linkSection(),
            separator(), healthRow(),
            separator(), footerRow(),
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 12, right: 16)
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
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }
    override func viewDidDisappear() {
        super.viewDidDisappear()
        refreshTimer?.invalidate(); refreshTimer = nil
    }

    // MARK: - Sections

    private func tempoRow() -> NSView {
        bpmLabel.font = Theme.monoDigits(size: 40, weight: .medium)
        bpmLabel.textColor = Theme.ink
        bpmLabel.setAccessibilityLabel("Tempo in beats per minute")
        let unit = NSTextField(labelWithString: "BPM")
        unit.font = .systemFont(ofSize: 11, weight: .semibold)
        unit.textColor = Theme.inkMuted
        let bpmStack = NSStackView(views: [bpmLabel, unit])
        bpmStack.alignment = .firstBaseline
        bpmStack.spacing = 6

        let up = nudgeButton("▲", #selector(nudgeUp))
        let down = nudgeButton("▼", #selector(nudgeDown))
        let nudges = NSStackView(views: [up, down])
        nudges.orientation = .vertical
        nudges.spacing = 4

        let row = NSStackView(views: [bpmStack, NSView(), nudges])
        row.alignment = .centerY
        row.distribution = .fill
        row.setHuggingPriority(.defaultLow, for: .horizontal)
        return row
    }

    private func transportRow() -> NSView {
        playButton.title = "Play"
        playButton.bezelStyle = .rounded
        playButton.controlSize = .large
        playButton.target = self
        playButton.action = #selector(toggleTransport)
        playButton.setButtonType(.momentaryPushIn)
        // Primary transport: mint-filled with dark label (bright accent needs dark ink for contrast).
        playButton.bezelColor = Theme.accent
        playButton.contentTintColor = Theme.inkOnAccent

        let tapButton = surfaceStyled(NSButton(title: "Tap", target: self, action: #selector(tapTempo)),
                                      radius: 11)
        tapButton.heightAnchor.constraint(equalToConstant: 40).isActive = true
        tapButton.setAccessibilityLabel("Tap tempo")

        let row = NSStackView(views: [playButton, tapButton])
        row.distribution = .fillProportionally
        row.spacing = 10
        playButton.setContentHuggingPriority(.defaultLow, for: .horizontal)
        row.widthAnchor.constraint(equalToConstant: Theme.popoverWidth - 32).isActive = true
        return row
    }

    private func linkSection() -> NSView {
        let title = NSTextField(labelWithString: "ABLETON LINK")
        title.font = .systemFont(ofSize: 11, weight: .semibold)
        title.textColor = Theme.inkMuted
        peersLabel.font = .systemFont(ofSize: 11)
        peersLabel.textColor = Theme.inkSecondary
        let titleRow = NSStackView(views: [title, NSView(), peersLabel])
        titleRow.alignment = .centerY
        titleRow.widthAnchor.constraint(equalToConstant: Theme.popoverWidth - 32).isActive = true

        modeControl.target = self
        modeControl.action = #selector(modeChanged)
        modeControl.segmentDistribution = .fillEqually
        modeControl.selectedSegmentBezelColor = Theme.accent // mint selected segment
        modeControl.setAccessibilityLabel("Ableton Link mode")
        modeControl.widthAnchor.constraint(equalToConstant: Theme.popoverWidth - 32).isActive = true

        modeHint.font = .systemFont(ofSize: 11)
        modeHint.textColor = Theme.inkMuted
        modeHint.lineBreakMode = .byWordWrapping
        modeHint.maximumNumberOfLines = 2
        modeHint.preferredMaxLayoutWidth = Theme.popoverWidth - 32

        let col = NSStackView(views: [titleRow, modeControl, modeHint])
        col.orientation = .vertical
        col.alignment = .leading
        col.spacing = 8
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
        row.widthAnchor.constraint(equalToConstant: Theme.popoverWidth - 32).isActive = true
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
        row.widthAnchor.constraint(equalToConstant: Theme.popoverWidth - 32).isActive = true
        return row
    }

    // MARK: - Helpers

    private func nudgeButton(_ title: String, _ action: Selector) -> NSButton {
        let b = surfaceStyled(NSButton(title: title, target: self, action: action), radius: 7)
        b.font = .systemFont(ofSize: 10)
        b.widthAnchor.constraint(equalToConstant: 30).isActive = true
        b.heightAnchor.constraint(equalToConstant: 22).isActive = true
        // Arrow glyphs read poorly under VoiceOver; give them real labels.
        b.setAccessibilityLabel(title == "▲" ? "Increase tempo" : "Decrease tempo")
        return b
    }

    /// A flat, layer-backed button on the popover's surface color with a hairline
    /// border (matches the mockup's dark rounded controls, vs. default bezels).
    private func surfaceStyled(_ b: NSButton, radius: CGFloat) -> NSButton {
        b.isBordered = false
        b.wantsLayer = true
        b.layer?.backgroundColor = Theme.surface.cgColor
        b.layer?.cornerRadius = radius
        b.layer?.borderWidth = 1
        b.layer?.borderColor = Theme.hairline.cgColor
        b.contentTintColor = Theme.inkSecondary
        return b
    }

    private func separator() -> NSView {
        let v = NSBox()
        v.boxType = .separator
        v.widthAnchor.constraint(equalToConstant: Theme.popoverWidth - 32).isActive = true
        return v
    }

    // MARK: - State

    private func refresh() {
        let snap = engine.snapshot()
        bpmLabel.stringValue = snap.tempo.description
        modeControl.selectedSegment = LinkMode.allCases.firstIndex(of: snap.mode) ?? 0
        let peerWord = snap.peerCount == 1 ? "peer" : "peers"
        peersLabel.stringValue = snap.linkIsReal ? "\(snap.peerCount) \(peerWord)" : "Link unavailable"
        modeHint.stringValue = hint(for: snap.mode)
        playButton.title = snap.transport == .playing ? "Stop" : "Play"
        playButton.contentTintColor = Theme.inkOnAccent // always mint-filled with dark label
        healthLabel.stringValue = "\(snap.activeOutputs) active · \(snap.missingOutputs) missing"
        pulse.setBeating(snap.transport == .playing, bpm: snap.tempo.bpm)
        view.window?.setAccessibilityLabel(
            "Synclock, \(snap.transport == .playing ? "playing" : "stopped"), \(snap.tempo) BPM, \(snap.mode.label)")
    }

    private func hint(for mode: LinkMode) -> String {
        switch mode {
        case .free: return "Free — local clock is master; Link is ignored."
        case .followLink: return "Following Link. Tempo and phase track the session; local BPM is read-only."
        case .leadLink: return "Leading Link. Your tempo and transport drive the session."
        }
    }

    // MARK: - Actions

    @objc private func toggleTransport() { engine.toggle(); refresh() }
    @objc private func nudgeUp() { engine.setTempo(engine.snapshot().tempo.nudged(by: 0.1)); refresh() }
    @objc private func nudgeDown() { engine.setTempo(engine.snapshot().tempo.nudged(by: -0.1)); refresh() }
    @objc private func tapTempo() {
        if let t = tap.tap(at: HostTime.nowNanos()) { engine.setTempo(t); refresh() }
    }
    @objc private func modeChanged() {
        let mode = LinkMode.allCases[modeControl.selectedSegment]
        engine.setMode(mode); refresh()
    }
    @objc private func openPrefs() { openPreferences?() }
}
