import AppKit

/// Sets the Dock / app-switcher / About icon at runtime.
///
/// Priority:
///  1. `AppIcon.icns` bundled as a Swift package resource (primary asset used by the DMG build too).
///  2. `AppIcon-1024.png` as a backup (handy during development if the `.icns` is regenerated).
///  3. SF Symbol fallback so launching directly via `swift run` never ships without *some* icon.
@MainActor
enum DockIcon {
    private static var didApply = false

    static func applyPlaceholderIfNeeded() {
        guard !didApply else { return }
        didApply = true

        if let icon = loadBundledIcon() {
            NSApp.applicationIconImage = icon
            return
        }

        if let fallback = loadSymbolFallback() {
            NSApp.applicationIconImage = fallback
        }
    }

    private static func loadBundledIcon() -> NSImage? {
        let bundle = Bundle.module
        if let url = bundle.url(forResource: "AppIcon", withExtension: "icns"),
           let image = NSImage(contentsOf: url) {
            return image
        }
        if let url = bundle.url(forResource: "AppIcon-1024", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            return image
        }
        return nil
    }

    private static func loadSymbolFallback() -> NSImage? {
        guard let base = NSImage(systemSymbolName: "waveform.path.ecg", accessibilityDescription: nil) else {
            return nil
        }
        let config = NSImage.SymbolConfiguration(pointSize: 128, weight: .regular)
        return base.withSymbolConfiguration(config)
    }
}
