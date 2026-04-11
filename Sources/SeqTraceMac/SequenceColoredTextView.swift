import AppKit

/// `NSTextView` for sequence editing. Context menus are supplied by the delegate via
/// `textView(_:menu:for:at:)` — `NSTextView` does not use `NSView.menu(for:)` for right-clicks.
final class SequenceColoredTextView: NSTextView {
    enum MenuMode {
        case singleFile
        case pairConsensus
    }

    weak var menuProxy: SequenceMenuProxy?
    var menuMode: MenuMode = .singleFile

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.type == .keyDown,
              event.modifierFlags.contains(.command),
              let ch = event.charactersIgnoringModifiers?.lowercased()
        else {
            return super.performKeyEquivalent(with: event)
        }
        if ch == "x" {
            menuProxy?.onCut?()
            return true
        }
        if ch == "c" {
            menuProxy?.onCopySelection?()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}
