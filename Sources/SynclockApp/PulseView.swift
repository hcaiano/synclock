import AppKit

/// The signature pulse — a small accent dot that flashes on the beat while the
/// clock runs. Respects Reduce Motion (becomes a steady lit dot). DESIGN.md:
/// the one delight; everything else defers to macOS idiom.
final class PulseView: NSView {
    private let dot = CALayer()
    private var beating = false
    private var bpm: Double = 120

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        dot.backgroundColor = Theme.accent.cgColor
        dot.cornerRadius = 4.5
        dot.frame = CGRect(x: 0, y: 0, width: 9, height: 9)
        layer?.addSublayer(dot)
        setAccessibilityLabel("Clock pulse")
    }
    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        dot.frame = CGRect(x: (bounds.width - 9) / 2, y: (bounds.height - 9) / 2, width: 9, height: 9)
    }

    private var reduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    func setBeating(_ on: Bool, bpm: Double) {
        let intervalChanged = abs(bpm - self.bpm) > 0.001
        self.bpm = bpm
        if on == beating && !intervalChanged { return }
        beating = on
        dot.removeAnimation(forKey: "pulse")
        guard on else { dot.opacity = 0.35; return }
        if reduceMotion { dot.opacity = 1; return } // steady lit dot
        let beat = 60.0 / max(bpm, 1)
        let anim = CABasicAnimation(keyPath: "opacity")
        anim.fromValue = 1.0
        anim.toValue = 0.25
        anim.duration = beat
        anim.timingFunction = CAMediaTimingFunction(name: .easeOut)
        anim.repeatCount = .infinity
        dot.add(anim, forKey: "pulse")
    }
}
