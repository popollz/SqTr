import SwiftUI

@main
struct SeqTraceMacApp: App {
    var body: some Scene {
        WindowGroup {
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
