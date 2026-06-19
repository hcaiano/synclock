import AppKit

/// A flat, layer-backed button (no system bezel) with explicit fill + title
/// colors, rounded corners, and a pressed state. The system `.rounded` bezel
/// renders as a glossy pill that fights the popover's flat native look; this
/// matches the mockup's custom controls.
///
/// Uses the standard NSButton action path (momentary push) so clicks always
/// fire — press feedback comes from `isHighlighted` in `updateLayer`, not from
/// intercepting `mouseDown` (which would swallow the action).
final class FlatButton: NSButton {
    var fillColor: NSColor = .clear { didSet { needsDisplay = true } }
    var pressedFillColor: NSColor?
    var borderColor: NSColor? { didSet { needsDisplay = true } }
    var cornerRadius: CGFloat = 10 { didSet { needsDisplay = true } }
    var titleColor: NSColor = .white { didSet { applyTitle() } }

    private let titleFont: NSFont

    init(title: String, font: NSFont, target: AnyObject?, action: Selector?) {
        self.titleFont = font
        super.init(frame: .zero)
        self.title = title
        self.target = target
        self.action = action
        isBordered = false
        wantsLayer = true
        setButtonType(.momentaryPushIn)
        applyTitle()
    }
    required init?(coder: NSCoder) { fatalError() }

    override var title: String { didSet { applyTitle() } }
    override var wantsUpdateLayer: Bool { true }

    // The popover lives in a menu-bar window that isn't key until first click.
    // Without this, the first click on a control only activates the window and
    // the action never fires — which reads as "the button does nothing".
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    private func applyTitle() {
        let p = NSMutableParagraphStyle(); p.alignment = .center
        attributedTitle = NSAttributedString(string: title, attributes: [
            .foregroundColor: titleColor, .font: titleFont, .paragraphStyle: p,
        ])
    }

    override func updateLayer() {
        guard let layer else { return }
        layer.cornerRadius = cornerRadius
        let base = fillColor
        let fill = isHighlighted
            ? (pressedFillColor ?? base.blended(withFraction: 0.14, of: .black) ?? base)
            : base
        layer.backgroundColor = fill.cgColor
        layer.borderWidth = borderColor == nil ? 0 : 1
        layer.borderColor = borderColor?.cgColor
    }
}
