import SwiftUI
import ClariDiffUI

@main
struct ClariDiffApp: App {
    var body: some Scene {
        WindowGroup("ClariDiff") {
            ClariDiffWorkspaceView()
        }
        .defaultSize(width: 1440, height: 860)
        .windowStyle(.hiddenTitleBar)
    }
}
