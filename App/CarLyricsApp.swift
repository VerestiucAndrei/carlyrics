import SwiftUI

@main
struct CarLyricsApp: App {
    @Environment(\.scenePhase) private var phase

    init() { Coordinator.shared.start() }

    var body: some Scene {
        WindowGroup { DebugView() }
            .onChange(of: phase) { _, new in
                if new == .active { Coordinator.shared.music.refresh("foreground") }
            }
    }
}
