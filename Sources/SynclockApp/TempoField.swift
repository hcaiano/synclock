import AppKit

/// The editable BPM number: click to type, scroll over it to nudge. Commit and
/// step are reported through closures so the view controller owns the engine.
final class TempoField: NSTextField {
    /// Called with +1 / -1 per accumulated scroll notch (scroll up = increase).
    var onScrollStep: ((Int) -> Void)?
    private var scrollAccum: CGFloat = 0

    override func scrollWheel(with event: NSEvent) {
        guard event.scrollingDeltaY != 0 else { super.scrollWheel(with: event); return }
        scrollAccum += event.scrollingDeltaY
        let threshold: CGFloat = event.hasPreciseScrollingDeltas ? 6 : 1
        while abs(scrollAccum) >= threshold {
            onScrollStep?(scrollAccum > 0 ? 1 : -1)
            scrollAccum -= (scrollAccum > 0 ? threshold : -threshold)
        }
    }

    /// True while the user is actively editing (so refresh shouldn't overwrite).
    var isEditing: Bool { currentEditor() != nil }
}
