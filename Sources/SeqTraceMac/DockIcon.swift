import AppKit

/// Sets a placeholder Dock icon (SF Symbol) until you ship a real `.icns` in the app bundle.
@MainActor
enum DockIcon {
    private static var didApply = false

    static func applyPlaceholderIfNeeded() {
        guard !didApply else { return }
        didApply = true
        guard let base = NSImage(systemSymbolName: "waveform.path.ecg", accessibilityDescription: nil) else {
            return
        }
        let config = NSImage.SymbolConfiguration(pointSize: 128, weight: .regular)
        guard let image = base.withSymbolConfiguration(config) else { return }
        NSApp.applicationIconImage = image
    }
}
