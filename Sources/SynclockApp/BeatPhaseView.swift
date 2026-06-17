import AppKit

/// The bar-phase indicator: a thin 4-segment bar that fills beat-by-beat across
/// the bar and snaps back on the downbeat, so you know exactly when to hit play
/// on external gear. The downbeat ("1") is emphasized. The signature moment of
/// delight (DESIGN.md) lives here and in the menubar pulse.
///
/// API-agnostic: it pulls the live phase through `phaseProvider` each frame, so
/// it works against whatever the engine exposes (`currentBarPhase` / beat index).
/// Respects Reduce Motion by showing discrete filled beats instead of a sweep.
final class BeatPhaseView: NSView {
    /// (barPhase 0..<1 across the whole bar, beatInBar 0...beats-1, running).
    var phaseProvider: () -> (phase: Double, beat: Int, running: Bool) = { (0, 0, false) }

    private let beats = 4
    private let segmentGap: CGFloat = 4
    private let corner: CGFloat = 2.5
    private var displayTimer: Timer?
    private var lastPhase: Double = 0
    private var lastBeat: Int = 0
    private var running = false

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        setContentHuggingPriority(.defaultHigh, for: .vertical)
        setAccessibilityRole(.progressIndicator)
        setAccessibilityLabel("Bar position")
    }
    required init?(coder: NSCoder) { fatalError() }

    override var intrinsicContentSize: NSSize { NSSize(width: NSView.noIntrinsicMetric, height: 6) }
    override var isFlipped: Bool { true }

    // MARK: - Drive

    /// Start/stop the per-frame sampling. Driven by the popover's appear/disappear.
    func setActive(_ active: Bool) {
        displayTimer?.invalidate(); displayTimer = nil
        guard active else { return }
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        // Sweep needs ~60fps; Reduce Motion only needs to catch beat boundaries.
        let interval = reduceMotion ? 1.0 / 15.0 : 1.0 / 60.0
        let t = Timer(timeInterval: interval, repeats: true) { [weak self] _ in self?.sample() }
        RunLoop.main.add(t, forMode: .common)
        displayTimer = t
        sample()
    }

    private func sample() {
        let (phase, beat, run) = phaseProvider()
        // Only repaint on meaningful change to avoid needless work when stopped.
        if run != running || beat != lastBeat || abs(phase - lastPhase) > 0.001 {
            running = run; lastBeat = beat; lastPhase = phase
            needsDisplay = true
        }
    }

    // MARK: - Draw

    override func draw(_ dirtyRect: NSRect) {
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let segW = (bounds.width - segmentGap * CGFloat(beats - 1)) / CGFloat(beats)
        let h = bounds.height

        for i in 0..<beats {
            let x = (segW + segmentGap) * CGFloat(i)
            let rect = NSRect(x: x, y: 0, width: segW, height: h)

            guard let ctx = NSGraphicsContext.current else { continue }
            ctx.saveGraphicsState()
            NSBezierPath(roundedRect: rect, xRadius: corner, yRadius: corner).setClip()

            Theme.surface.setFill()
            rect.fill()

            if running {
                // Fraction of THIS segment to fill.
                let fill: CGFloat
                if reduceMotion {
                    fill = i <= lastBeat ? 1 : 0                       // discrete: solid up to active beat
                } else if i < lastBeat {
                    fill = 1                                           // passed beats: full
                } else if i == lastBeat {
                    let frac = lastPhase * Double(beats) - Double(lastBeat)
                    fill = CGFloat(min(max(frac, 0), 1))              // active beat: sub-beat sweep
                } else {
                    fill = 0
                }
                if fill > 0 {
                    // Passed beats sit a touch quieter; the active beat is full strength.
                    Theme.accent.withAlphaComponent(i < lastBeat ? 0.8 : 1).setFill()
                    NSRect(x: x, y: 0, width: segW * fill, height: h).fill()
                }
            }
            ctx.restoreGraphicsState()
        }
    }
}
