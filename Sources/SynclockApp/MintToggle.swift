import AppKit

/// A compact on/off switch that turns Synclock **mint** when on. The system
/// `NSSwitch` only tints to the user's system accent (usually blue), which
/// fights the brand; this matches the Play button and the accent everywhere.
/// Animated knob, click + Space to toggle, VoiceOver as a switch.
final class MintToggle: NSControl {
    var isOn: Bool = false {
        didSet { guard isOn != oldValue else { return }; updateAppearance(animated: true) }
    }

    private let knob = CALayer()
    private let trackW: CGFloat = 40
    private let trackH: CGFloat = 24
    private let inset: CGFloat = 2
    private var knobD: CGFloat { trackH - inset * 2 }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = trackH / 2
        knob.cornerRadius = knobD / 2
        knob.backgroundColor = NSColor.white.cgColor
        knob.shadowColor = NSColor.black.cgColor
        knob.shadowOpacity = 0.22
        knob.shadowRadius = 1.5
        knob.shadowOffset = CGSize(width: 0, height: -0.5)
        layer?.addSublayer(knob)
        setAccessibilityRole(.checkBox)   // closest switch-like role
        updateAppearance(animated: false)
    }
    required init?(coder: NSCoder) { fatalError() }

    override var intrinsicContentSize: NSSize { NSSize(width: trackW, height: trackH) }
    override var allowsVibrancy: Bool { false }
    override var acceptsFirstResponder: Bool { isEnabled }

    override func layout() {
        super.layout()
        layer?.cornerRadius = bounds.height / 2
        positionKnob(animated: false)
        updateTrack(animated: false)
    }

    private func updateAppearance(animated: Bool) {
        updateTrack(animated: animated)
        positionKnob(animated: animated)
        setAccessibilityValue(isOn)
    }

    private func updateTrack(animated: Bool) {
        withAnimations(animated) { layer?.backgroundColor = (isOn ? Theme.accent : Theme.switchTrackOff).cgColor }
    }

    private func positionKnob(animated: Bool) {
        let y = (bounds.height - knobD) / 2
        let x = isOn ? bounds.width - knobD - inset : inset
        withAnimations(animated) { knob.frame = CGRect(x: x, y: y, width: knobD, height: knobD) }
    }

    private func withAnimations(_ animated: Bool, _ body: () -> Void) {
        CATransaction.begin()
        CATransaction.setDisableActions(!animated)
        CATransaction.setAnimationDuration(0.18)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))
        body()
        CATransaction.commit()
    }

    private func toggle() {
        guard isEnabled else { return }
        isOn.toggle()
        sendAction(action, to: target)
    }

    override func mouseDown(with event: NSEvent) { toggle() }
    override func keyDown(with event: NSEvent) {
        if event.charactersIgnoringModifiers == " " { toggle() } else { super.keyDown(with: event) }
    }
}
