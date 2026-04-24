import SwiftUI

@main
struct SeqTraceMacApp: App {
    var body: some Scene {
        WindowGroup(AppInfo.name) {
            ContentView()
                .onAppear {
                    DockIcon.applyPlaceholderIfNeeded()
                }
        }
        .windowResizability(.contentMinSize)
        .commands {
            AppMenuCommands()
        }
    }
}
