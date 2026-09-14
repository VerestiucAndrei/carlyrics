import MediaPlayer
import UIKit

/// Tier A. The system player reports the Music app's state locally with an exact position.
/// `snapshot` changes only on track change, play/pause, or a detected seek.
@MainActor
final class AppleMusicSource: ObservableObject {
    struct Snapshot: Equatable {
        var id: MPMediaEntityPersistentID
        var title: String
        var artist: String
        var album: String
        var duration: TimeInterval
        var position: TimeInterval
        var sampledAt: Date
        var isPlaying: Bool

        var expectedPosition: TimeInterval { isPlaying ? position + Date().timeIntervalSince(sampledAt) : position }
    }

    @Published private(set) var snapshot: Snapshot?
    private let player = MPMusicPlayerController.systemMusicPlayer
    private var lastRaw: TimeInterval = -1
    private var staleRun = 0
    private var poll: Timer?

    var authorization: MPMediaLibraryAuthorizationStatus { MPMediaLibrary.authorizationStatus() }

    func start() {
        MPMediaLibrary.requestAuthorization { _ in Task { @MainActor in self.refresh("auth") } }
        player.beginGeneratingPlaybackNotifications()
        for name in [Notification.Name.MPMusicPlayerControllerNowPlayingItemDidChange,
                     .MPMusicPlayerControllerPlaybackStateDidChange] {
            NotificationCenter.default.addObserver(forName: name, object: player, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.refresh("notification") }
            }
        }
        // ponytail: 2s poll for seeks; the system player sends no seek notification.
        poll = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh("poll") }
        }
        refresh("start")
    }

    func refresh(_ reason: String) {
        guard let item = player.nowPlayingItem else {
            if snapshot != nil { snapshot = nil }
            return
        }
        let playing = player.playbackState == .playing
        let raw = player.currentPlaybackTime
        // In the background the player hands back a frozen position. A playing track never
        // reads the same value twice, so an identical reading is stale and must not re-anchor.
        let stale = playing && raw == lastRaw
        lastRaw = raw
        if stale {
            staleRun += 1
            if staleRun == 1 || staleRun % 30 == 0 { Log.shared.add("stale position \(raw) x\(staleRun) (\(reason))") }
        } else {
            staleRun = 0
        }

        // Backgrounded, the player extrapolates locally from its last sync: it keeps counting the
        // old track through a track change, and never sees a seek. Only the foreground reading
        // is truth; a background track change starts at 0 and the foreground refresh resyncs.
        let active = UIApplication.shared.applicationState == .active
        let trackChanged = snapshot?.id != item.persistentID
        let stateChanged = snapshot?.isPlaying != playing
        var position = raw
        if trackChanged {
            if !active || snapshot.map({ abs(raw - $0.expectedPosition) < 2 }) == true { position = 0 }
        } else if !stateChanged {
            guard active, let s = snapshot, !stale else { return }
            let delta = raw - s.expectedPosition
            guard abs(delta) > 1 else { return }
            Log.shared.add("seek \(String(format: "%+.1f", delta))s")
        }
        Log.shared.add("\(reason) \(active ? "fg" : "bg") \(item.title ?? "?") raw=\(String(format: "%.1f", raw)) pos=\(String(format: "%.1f", position)) \(playing ? "playing" : "paused")")
        snapshot = Snapshot(id: item.persistentID, title: item.title ?? "", artist: item.artist ?? "",
                            album: item.albumTitle ?? "", duration: item.playbackDuration,
                            position: position, sampledAt: .now, isPlaying: playing)
    }
}
