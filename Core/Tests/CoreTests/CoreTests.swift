import XCTest
@testable import Core

final class CoreTests: XCTestCase {
    func testGroupsParsedFromProfileBlob() {
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <plist version="1.0"><dict>
          <key>Entitlements</key><dict>
            <key>com.apple.security.application-groups</key>
            <array><string>group.com.carlyrics.ABCDE12345</string></array>
          </dict>
        </dict></plist>
        """
        var blob = Data([0x30, 0x82, 0x01, 0x00, 0xFF])   // fake CMS bytes
        blob.append(Data(plist.utf8))
        blob.append(Data([0x00, 0xFF, 0x30]))
        XCTAssertEqual(AppGroup.groups(inProfile: blob), ["group.com.carlyrics.ABCDE12345"])
        XCTAssertEqual(AppGroup.groups(inProfile: Data([1, 2, 3])), [])
    }

    func testSharedStateRoundTrip() throws {
        let s = sample(playing: true)
        let data = try SharedStore.encoder.encode(s)
        XCTAssertEqual(try SharedStore.decoder.decode(SharedState.self, from: data), s)
    }

    func testTimelinePlayingStartsAtCurrentLine() {
        let s = sample(playing: true)                  // position 12s at positionDate
        let now = s.positionDate.addingTimeInterval(1) // 13s in => line at 10s is current
        let f = LyricTimeline.frames(for: s, now: now)
        XCTAssertEqual(f.first?.date, now)
        XCTAssertEqual(f.map(\.current), ["L10", "L20", "L30"])
        XCTAssertEqual(f.map(\.next), ["L20", "L30", nil])
        XCTAssertEqual(f[1].date.timeIntervalSince(s.anchor), 20 - LyricTimeline.schedulingBias, accuracy: 1e-6)
    }

    func testTimelineBeforeFirstLineShowsTitle() {
        var s = sample(playing: true); s.position = -1  // e.g. offset larger than position
        let f = LyricTimeline.frames(for: s, now: s.positionDate)
        XCTAssertEqual(f.first?.current, "Song")
        XCTAssertEqual(f.first?.next, "L0")
        XCTAssertEqual(f.count, 5)
    }

    func testTimelinePausedIsSingleFrozenFrame() {
        let s = sample(playing: false)
        let f = LyricTimeline.frames(for: s, now: s.positionDate.addingTimeInterval(500))
        XCTAssertEqual(f.map(\.current), ["L10"])
    }

    func testTimelineNoLinesShowsTitleArtist() {
        var s = sample(playing: true); s.lines = []
        XCTAssertEqual(LyricTimeline.frames(for: s, now: .now).map(\.current), ["Song"])
    }

    private func sample(playing: Bool) -> SharedState {
        SharedState(source: "test", title: "Song", artist: "Artist", position: 12,
                    positionDate: Date(timeIntervalSince1970: 1_000_000), isPlaying: playing,
                    duration: 40, offset: 0,
                    lines: [0, 10, 20, 30].map { .init(t: TimeInterval($0), text: "L\($0)") },
                    updatedAt: Date(timeIntervalSince1970: 1_000_000))
    }
}
