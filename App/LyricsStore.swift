import Foundation
import Core

/// Documents/lyrics/<key>.lrc. Visible in the Files app, so dropping a hand-fixed file there is the
/// local override: it is read before anything is fetched.
final class LyricsStore {
    static let shared = LyricsStore()
    let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("lyrics")

    struct Result { var lines: [SharedState.Line]; var status: String }

    static func key(artist: String, title: String) -> String {
        let raw = "\(artist) - \(title)".lowercased()
        let safe = raw.map { $0.isLetter || $0.isNumber || $0 == " " || $0 == "-" ? $0 : "_" }
        return String(String(safe).prefix(120))
    }

    func lyrics(title: String, artist: String, album: String, duration: TimeInterval) async -> Result {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent(Self.key(artist: artist, title: title) + ".lrc")
        if let text = try? String(contentsOf: file, encoding: .utf8) {
            let lines = LRC.parse(text)
            return Result(lines: lines, status: "file (\(lines.count) lines)")
        }
        do {
            guard let lrc = try await LRCLIB.fetch(title: title, artist: artist, album: album, duration: duration) else {
                return Result(lines: [], status: "lrclib: not found")
            }
            try lrc.write(to: file, atomically: true, encoding: .utf8)
            let lines = LRC.parse(lrc)
            return Result(lines: lines, status: "lrclib (\(lines.count) lines)")
        } catch {
            return Result(lines: [], status: "lrclib error: \(error.localizedDescription)")
        }
    }
}
