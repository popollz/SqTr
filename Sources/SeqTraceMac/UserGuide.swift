import AppKit

enum UserGuideOpener {
    /// Opens the bundled `USER_GUIDE.md` in the default app (Preview, TextEdit, etc.).
    @MainActor
    static func openBundledGuide() {
        guard let url = Bundle.module.url(forResource: "USER_GUIDE", withExtension: "md") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}
