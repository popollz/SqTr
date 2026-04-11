import AppKit
import SwiftUI

struct AppMenuCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About \(AppInfo.name)") {
                AboutPanelPresenter.show()
            }
        }
        CommandGroup(after: .help) {
            Button("\(AppInfo.name) User Guide") {
                UserGuideOpener.openBundledGuide()
            }
            .keyboardShortcut("?", modifiers: [.command, .shift])
        }
    }
}

private enum AboutPanelPresenter {
    @MainActor
    static func show() {
        let credits = """
        \(AppInfo.marketingDescription)

        Feedback: \(AppInfo.feedbackContact)
        """
        let attr = NSAttributedString(
            string: credits,
            attributes: [
                .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                .foregroundColor: NSColor.secondaryLabelColor,
            ]
        )
        NSApplication.shared.orderFrontStandardAboutPanel(options: [
            .applicationName: AppInfo.name,
            .applicationVersion: AppInfo.marketingVersion,
            .version: "Build \(AppInfo.build)",
            .credits: attr,
        ])
    }
}
