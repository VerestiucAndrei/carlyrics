import Foundation

public enum LRC {
    /// Parses standard and enhanced LRC. Multiple timestamps per line are expanded; word-level
    /// `<mm:ss.xx>` tags are stripped; `[offset:ms]` is applied here and nowhere else.
    public static func parse(_ text: String) -> [SharedState.Line] {
        var offset: TimeInterval = 0
        var out: [SharedState.Line] = []
        for raw in text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline) {
            var rest = Substring(raw.trimmingCharacters(in: .whitespaces))
            var times: [TimeInterval] = []
            while rest.hasPrefix("["), let close = rest.firstIndex(of: "]") {
                let tag = String(rest[rest.index(after: rest.startIndex)..<close])
                rest = rest[rest.index(after: close)...]
                if let t = timestamp(tag) {
                    times.append(t)
                } else if tag.lowercased().hasPrefix("offset:"),
                          let ms = Double(tag.dropFirst(7).trimmingCharacters(in: .whitespaces)) {
                    offset = ms / 1000
                }
            }
            guard !times.isEmpty else { continue }
            let body = rest.replacing(wordTag, with: "").trimmingCharacters(in: .whitespaces)
            for t in times { out.append(.init(t: t, text: body.isEmpty ? "♪" : body)) }
        }
        // Positive offset means lyrics are late and should show earlier, hence subtraction.
        return out.map { .init(t: $0.t - offset, text: $0.text) }.sorted { $0.t < $1.t }
    }

    private static let wordTag = /<\d+:\d+(?:[.:]\d+)?>/

    /// `mm:ss.xx`, `mm:ss`, or the rarer `mm:ss:xx`.
    static func timestamp(_ s: String) -> TimeInterval? {
        let parts = s.split(separator: ":")
        guard parts.count >= 2, let m = Double(parts[0]),
              let sec = Double(parts[1...].joined(separator: ".")) else { return nil }
        return m * 60 + sec
    }
}
