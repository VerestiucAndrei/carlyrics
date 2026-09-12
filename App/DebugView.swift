import SwiftUI
import Core

struct DebugView: View {
    @ObservedObject private var c = Coordinator.shared
    @ObservedObject private var log = Log.shared

    var body: some View {
        NavigationStack {
            List {
                Section("Now playing") {
                    if let s = c.music.snapshot {
                        Text("\(s.artist) - \(s.title)")
                        LabeledContent("state", value: s.isPlaying ? "playing" : "paused")
                        LabeledContent("position", value: String(format: "%.1f / %.0f s", s.position, s.duration))
                    } else {
                        Text("nothing").foregroundStyle(.secondary)
                    }
                    LabeledContent("lyrics", value: c.lyricsStatus)
                    NavigationLink("Karaoke view") { KaraokeView() }
                }
                Section("Permissions") {
                    LabeledContent("media library", value: "\(c.music.authorization.rawValue) (3 = authorized)")
                    LabeledContent("location", value: "\(KeepAlive.shared.status.rawValue) (3 = always)")
                }
                Section("App group") {
                    LabeledContent("id", value: AppGroup.id)
                    Text(AppGroup.containerURL?.path ?? "NOT ENTITLED: containerURL is nil")
                        .font(.caption.monospaced())
                }
                Section("Shared state") {
                    Text(c.state.map(pretty) ?? "none").font(.caption.monospaced())
                }
                Section {
                    Button("Write test song + reload widget") { c.writeTestSong() }
                    Button("Clear", role: .destructive) { c.clear() }
                }
                Section("Log") {
                    ForEach(Array(log.lines.enumerated().reversed()), id: \.offset) {
                        Text($0.element).font(.caption.monospaced())
                    }
                }
            }
            .navigationTitle("CarLyrics")
        }
    }

    private func pretty(_ s: SharedState) -> String {
        var short = s; short.lines = Array(s.lines.prefix(3))
        return (try? SharedStore.encoder.encode(short)).flatMap { String(data: $0, encoding: .utf8) } ?? "?"
    }
}
