import AppKit

/// Synclock palette + metrics, from DESIGN.md. Restrained: neutral surfaces,
/// one Slider Cyan accent reserved for active/selected/primary + the pulse,
/// derived from the app icon (deep navy + glowing cyan slider mark).
enum Theme {
    // Brand accent (kept) — the one cyan, reserved for active/primary controls.
    static let accent = NSColor(srgbRed: 0x4F/255, green: 0xE3/255, blue: 0xEC/255, alpha: 1) // Slider Cyan (icon)
    static let inkOnAccent = NSColor(srgbRed: 0x04/255, green: 0x22/255, blue: 0x3E/255, alpha: 1) // deep navy ink on bright cyan
    static let amber = NSColor(srgbRed: 0xE2/255, green: 0xA2/255, blue: 0x3B/255, alpha: 1)

    // Neutrals → macOS system semantic colors so the widget renders like a
    // native menu (vibrant labels/separators that adapt to the material).
    static let ink = NSColor.labelColor
    static let inkSecondary = NSColor.secondaryLabelColor
    static let inkMuted = NSColor.tertiaryLabelColor
    static let surface = NSColor.quaternaryLabelColor          // subtle control fill
    static let switchTrackOff = NSColor.tertiaryLabelColor     // off-state pill for MintToggle
    static let hairline = NSColor.separatorColor

    static let popoverWidth: CGFloat = 300

    static func monoDigits(size: CGFloat, weight: NSFont.Weight) -> NSFont {
        let base = NSFont.systemFont(ofSize: size, weight: weight)
        let desc = base.fontDescriptor.addingAttributes([
            .featureSettings: [[
                NSFontDescriptor.FeatureKey.typeIdentifier: kNumberSpacingType,
                NSFontDescriptor.FeatureKey.selectorIdentifier: kMonospacedNumbersSelector
            ]]
        ])
        return NSFont(descriptor: desc, size: size) ?? base
    }
}
