import Foundation

/// lrclib.net: open, keyless. `/get` matches on duration (about 2s tolerance), which is the
/// master-mismatch defence; `/search` is the fallback with the same check applied here.
enum LRCLIB {
    struct Track: Decodable {
        var duration: Double?
        var syncedLyrics: String?
    }

    static func fetch(title: String, artist: String, album: String, duration: TimeInterval) async throws -> String? {
        var q = [URLQueryItem(name: "track_name", value: title), URLQueryItem(name: "artist_name", value: artist)]
        if !album.isEmpty { q.append(URLQueryItem(name: "album_name", value: album)) }
        q.append(URLQueryItem(name: "duration", value: String(Int(duration.rounded()))))
        if let t: Track = try await get("get", q), let s = t.syncedLyrics, !s.isEmpty { return s }

        let candidates: [Track] = try await get("search", Array(q.prefix(2))) ?? []
        return candidates.first {
            $0.syncedLyrics?.isEmpty == false && abs(($0.duration ?? -100) - duration) <= 2
        }?.syncedLyrics
    }

    private static func get<T: Decodable>(_ path: String, _ query: [URLQueryItem]) async throws -> T? {
        var c = URLComponents(string: "https://lrclib.net/api/\(path)")!
        c.queryItems = query
        var req = URLRequest(url: c.url!)
        req.setValue("CarLyrics/0.1 (https://github.com/VerestiucAndrei/carlyrics)", forHTTPHeaderField: "Lrclib-Client")
        let (data, resp) = try await URLSession.shared.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        if code == 404 { return nil }
        guard (200..<300).contains(code) else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
