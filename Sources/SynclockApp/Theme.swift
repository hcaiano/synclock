import AppKit

/// Synclock palette + metrics, from DESIGN.md. Restrained: neutral surfaces,
/// one Slider Cyan accent reserved for active/selected/primary + the pulse,
/// derived from the app icon (deep navy + glowing cyan slider mark).
enum Theme {
    static let accent = NSColor(srgbRed: 0x4F/255, green: 0xE3/255, blue: 0xEC/255, alpha: 1) // Slider Cyan (icon)
    static let inkOnAccent = NSColor(srgbRed: 0x04/255, green: 0x22/255, blue: 0x3E/255, alpha: 1) // deep navy ink on bright cyan
    static let ink = NSColor(srgbRed: 0xF2/255, green: 0xF4/255, blue: 0xF0/255, alpha: 1)
    static let inkSecondary = NSColor(white: 1, alpha: 0.72)
    static let inkMuted = NSColor(white: 1, alpha: 0.45)
    static let surface = NSColor(white: 1, alpha: 0.08)
    static let switchTrackOff = NSColor(white: 1, alpha: 0.20) // off-state pill for MintToggle
    static let hairline = NSColor(white: 1, alpha: 0.10)
    static let amber = NSColor(srgbRed: 0xE2/255, green: 0xA2/255, blue: 0x3B/255, alpha: 1)

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
