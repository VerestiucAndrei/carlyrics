import Foundation

/// The single document the host app writes and the widget reads. Everything the widget needs
/// to render a full song is here; the widget never resolves, fetches, or corrects anything.
public struct SharedState: Codable, Equatable {
    public struct Line: Codable, Equatable {
        public var t: TimeInterval
        public var text: String
        public init(t: TimeInterval, text: String) { self.t = t; self.text = text }
    }

    public var source: String          // "appleMusic" | "spotify" | "shazam" | "test"
    public var title: String
    public var artist: String
    public var position: TimeInterval  // playback position sampled at `positionDate`
    public var positionDate: Date
    public var isPlaying: Bool
    public var duration: TimeInterval  // 0 = unknown
    public var offset: TimeInterval    // calibration + route latency, applied exactly once (here)
    public var lines: [Line]
    public var updatedAt: Date

    public init(source: String, title: String, artist: String, position: TimeInterval, positionDate: Date,
                isPlaying: Bool, duration: TimeInterval, offset: TimeInterval, lines: [Line], updatedAt: Date) {
        self.source = source; self.title = title; self.artist = artist
        self.position = position; self.positionDate = positionDate; self.isPlaying = isPlaying
        self.duration = duration; self.offset = offset; self.lines = lines; self.updatedAt = updatedAt
    }

    /// Wall-clock instant at which playback position was 0.
    public var anchor: Date { positionDate.addingTimeInterval(-position) }
}

public enum SharedStore {
    public static let fileName = "now.json"

    public static var url: URL? { AppGroup.containerURL?.appendingPathComponent(fileName) }

    public static func load() -> SharedState? {
        guard let url, let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(SharedState.self, from: data)
    }

    public static func save(_ state: SharedState) throws {
        guard let url else { throw CocoaError(.fileNoSuchFile) }
        try encoder.encode(state).write(to: url, options: .atomic)
    }

    public static func clear() {
        if let url { try? FileManager.default.removeItem(at: url) }
    }

    public static let encoder: JSONEncoder = {
        let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; e.outputFormatting = [.prettyPrinted, .sortedKeys]; return e
    }()
    public static let decoder: JSONDecoder = {
        let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d
    }()
}
