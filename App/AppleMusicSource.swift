import MediaPlayer

/// Tier A. The system player reports the Music app's state locally with an exact position.
@MainActor
final class AppleMusicSource: ObservableObject {
    struct Snapshot: Equatable {
        var title: String
        var artist: String
        var album: String
        var duration: TimeInterval
        var position: TimeInterval
        var sampledAt: Date
        var isPlaying: Bool
    }

    @Published private(set) var snapshot: Snapshot?
    private let player = MPMusicPlayerController.systemMusicPlayer

    var authorization: MPMediaLibraryAuthorizationStatus { MPMediaLibrary.authorizationStatus() }
    var currentPosition: TimeInterval { player.currentPlaybackTime }

    func start() {
        MPMediaLibrary.requestAuthorization { _ in Task { @MainActor in self.refresh() } }
        player.beginGeneratingPlaybackNotifications()
        for name in [Notification.Name.MPMusicPlayerControllerNowPlayingItemDidChange,
                     .MPMusicPlayerControllerPlaybackStateDidChange] {
            NotificationCenter.default.addObserver(forName: name, object: player, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.refresh() }
            }
        }
        refresh()
    }

    func refresh() {
        guard let item = player.nowPlayingItem else { snapshot = nil; return }
        snapshot = Snapshot(title: item.title ?? "", artist: item.artist ?? "", album: item.albumTitle ?? "",
                            duration: item.playbackDuration, position: player.currentPlaybackTime,
                            sampledAt: .now, isPlaying: player.playbackState == .playing)
    }
}
