import AppKit

/// Synclock palette + metrics, from DESIGN.md. Restrained: neutral surfaces,
/// one accent (#2F6BFF) reserved for active/selected/primary + the pulse.
enum Theme {
    static let accent = NSColor(srgbRed: 0x2F/255, green: 0x6B/255, blue: 0xFF/255, alpha: 1)
    static let ink = NSColor(srgbRed: 0xF2/255, green: 0xF4/255, blue: 0xF0/255, alpha: 1)
    static let inkSecondary = NSColor(white: 1, alpha: 0.72)
    static let inkMuted = NSColor(white: 1, alpha: 0.45)
    static let surface = NSColor(white: 1, alpha: 0.08)
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
