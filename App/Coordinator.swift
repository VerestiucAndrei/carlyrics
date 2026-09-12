import Foundation
import Combine
import WidgetKit
import Core

let widgetKind = "LyricsWidget"

/// Source snapshot -> lyrics -> SharedState -> widget reload. The only writer of the shared file.
@MainActor
final class Coordinator: ObservableObject {
    static let shared = Coordinator()

    let music = AppleMusicSource()
    @Published private(set) var state: SharedState? = SharedStore.load()
    @Published private(set) var lyricsStatus = "-"

    private var trackKey: String?
    private var lines: [SharedState.Line] = []
    private var sub: AnyCancellable?
    private var reloadWork: DispatchWorkItem?

    func start() {
        KeepAlive.shared.start()
        music.start()
        sub = music.$snapshot.dropFirst().sink { [weak self] in self?.handle($0) }
    }

    /// Writes a synthetic song so the widget path can be tested without a music source.
    func writeTestSong() {
        trackKey = "test"
        lines = (0..<12).map { .init(t: Double($0) * 5, text: "Test line \($0 + 1)") }
        publish(SharedState(source: "test", title: "Test Song", artist: "CarLyrics", position: 0, positionDate: .now,
                            isPlaying: true, duration: 60, offset: 0, lines: lines, updatedAt: .now))
    }

    func clear() {
        trackKey = nil; lines = []
        SharedStore.clear(); state = nil; reload()
    }

    private func handle(_ snap: AppleMusicSource.Snapshot?) {
        guard let snap else { clear(); return }
        let key = LyricsStore.key(artist: snap.artist, title: snap.title)
        if key != trackKey {
            trackKey = key; lines = []; lyricsStatus = "resolving"
            Log.shared.add("track: \(snap.artist) - \(snap.title) (\(Int(snap.duration))s)")
            Task {
                let r = await LyricsStore.shared.lyrics(title: snap.title, artist: snap.artist, album: snap.album, duration: snap.duration)
                guard trackKey == key else { return }
                lines = r.lines; lyricsStatus = r.status
                Log.shared.add("lyrics: \(r.status)")
                if let snap = music.snapshot { handle(snap) }   // republish with lines attached
            }
        }
        publish(SharedState(source: "appleMusic", title: snap.title, artist: snap.artist, position: snap.position,
                            positionDate: snap.sampledAt, isPlaying: snap.isPlaying, duration: snap.duration,
                            offset: 0, lines: lines, updatedAt: .now))
    }

    private func publish(_ s: SharedState) {
        do { try SharedStore.save(s); state = s; reload() }
        catch { Log.shared.add("save failed: \(error)") }
    }

    private func reload() {
        reloadWork?.cancel()
        let w = DispatchWorkItem { WidgetCenter.shared.reloadTimelines(ofKind: widgetKind) }
        reloadWork = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: w)
    }
}
