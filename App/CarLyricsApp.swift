import SwiftUI

@main
struct CarLyricsApp: App {
    init() { Coordinator.shared.start() }

    var body: some Scene {
        WindowGroup { DebugView() }
    }
}
