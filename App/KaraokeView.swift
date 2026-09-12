import SwiftUI
import Core

/// Ground truth for sync checks: if this is in time and the widget is not, the bug is in scheduling.
struct KaraokeView: View {
    @ObservedObject private var c = Coordinator.shared

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { ctx in
            if let s = c.state, !s.lines.isEmpty {
                let pos = s.isPlaying ? ctx.date.timeIntervalSince(s.anchor) : s.position
                let current = LyricTimeline.index(at: pos - s.offset, in: s.lines)
                ScrollViewReader { proxy in
                    List(s.lines.indices, id: \.self) { i in
                        Text(s.lines[i].text)
                            .font(i == current ? .title3.bold() : .body)
                            .foregroundStyle(i == current ? .primary : .secondary)
                            .id(i)
                    }
                    .onChange(of: current) { _, new in
                        if let new { withAnimation { proxy.scrollTo(new, anchor: .center) } }
                    }
                }
                .navigationTitle(String(format: "%.1fs", pos))
            } else {
                Text("No lyrics").foregroundStyle(.secondary)
            }
        }
    }
}
