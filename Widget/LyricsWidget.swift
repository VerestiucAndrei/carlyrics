import WidgetKit
import SwiftUI
import Core

struct LyricEntry: TimelineEntry {
    let date: Date
    let current: String
    let next: String?
    let source: String

    static let placeholder = LyricEntry(date: .now, current: "Lyrics appear here", next: "one line ahead", source: "")
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> LyricEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (LyricEntry) -> Void) {
        completion(getTimelineNow().entries.first ?? .placeholder)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LyricEntry>) -> Void) {
        completion(getTimelineNow())
    }

    /// Read one JSON file, map to entries. No networking, no parsing beyond JSON.
    private func getTimelineNow() -> Timeline<LyricEntry> {
        let now = Date()
        guard let s = SharedStore.load() else {
            return Timeline(entries: [LyricEntry(date: now, current: "No song", next: nil, source: "")], policy: .never)
        }
        let entries = LyricTimeline.frames(for: s, now: now).map {
            LyricEntry(date: $0.date, current: $0.current, next: $0.next, source: s.source)
        }
        // The host app reloads on every state change; the end-of-song policy is only a safety net.
        let policy: TimelineReloadPolicy = s.isPlaying && s.duration > 0
            ? .after(s.anchor.addingTimeInterval(s.duration + 1)) : .never
        return Timeline(entries: entries, policy: policy)
    }
}

struct LyricsWidgetView: View {
    let entry: LyricEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entry.current)
                .font(.title3.weight(.semibold))
                .lineLimit(3)
                .minimumScaleFactor(0.6)
            if let next = entry.next {
                Text(next).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer(minLength: 0)
            Text(entry.source).font(.caption2).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(.background, for: .widget)
    }
}

@main
struct LyricsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "LyricsWidget", provider: Provider()) { LyricsWidgetView(entry: $0) }
            .configurationDisplayName("Lyrics")
            .description("Synced lyrics for the current song.")
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}
