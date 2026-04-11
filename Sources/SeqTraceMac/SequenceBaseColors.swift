import AppKit

enum SequenceBaseColors {
    /// Matches chromatogram styling: A green, C blue, G black/dark, T red; others secondary.
    static func nsColor(for character: Character) -> NSColor {
        switch String(character).uppercased() {
        case "A": return NSColor.systemGreen
        case "C": return NSColor.systemBlue
        case "G": return NSColor.labelColor
        case "T": return NSColor.systemRed
        default: return NSColor.secondaryLabelColor
        }
    }

    static func attributedString(for plain: String, font: NSFont) -> NSAttributedString {
        let m = NSMutableAttributedString(
            string: plain,
            attributes: [
                .font: font,
                .foregroundColor: NSColor.labelColor,
            ]
        )
        let ns = plain as NSString
        for i in 0..<ns.length {
            let r = NSRange(location: i, length: 1)
            let ch = ns.substring(with: r)
            if ch == "\n" { continue }
            let c = Character(ch)
            m.addAttribute(.foregroundColor, value: nsColor(for: c), range: r)
        }
        return m
    }
}
