import SwiftUI
import WidgetKit
import Core

let widgetKind = "LyricsWidget"

struct DebugView: View {
    @StateObject private var log = Log.shared
    @State private var state: SharedState? = SharedStore.load()

    var body: some View {
        NavigationStack {
            List {
                Section("App group") {
                    LabeledContent("id", value: AppGroup.id)
                    Text(AppGroup.containerURL?.path ?? "NOT ENTITLED: containerURL is nil")
                        .font(.caption.monospaced())
                }
                Section("Shared state") {
                    Text(state.map(pretty) ?? "none").font(.caption.monospaced())
                }
                Section {
                    Button("Write test song + reload widget", action: writeTest)
                    Button("Clear", role: .destructive) { SharedStore.clear(); refresh() }
                }
                Section("Log") {
                    ForEach(Array(log.lines.enumerated()), id: \.offset) { Text($0.element).font(.caption.monospaced()) }
                }
            }
            .navigationTitle("CarLyrics")
            .refreshable { refresh() }
        }
    }

    private func refresh() { state = SharedStore.load() }

    private func writeTest() {
        let lines = (0..<12).map { SharedState.Line(t: Double($0) * 5, text: "Test line \($0 + 1)") }
        let s = SharedState(source: "test", title: "Test Song", artist: "CarLyrics", position: 0, positionDate: .now,
                            isPlaying: true, duration: 60, offset: 0, lines: lines, updatedAt: .now)
        do {
            try SharedStore.save(s)
            WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
            log.add("wrote test song, reloaded widget")
        } catch {
            log.add("save failed: \(error)")
        }
        refresh()
    }

    private func pretty(_ s: SharedState) -> String {
        (try? SharedStore.encoder.encode(s)).flatMap { String(data: $0, encoding: .utf8) } ?? "?"
    }
}
