import Foundation

public struct LyricFrame: Equatable {
    public let date: Date
    public let current: String
    public let next: String?
    public init(date: Date, current: String, next: String?) { self.date = date; self.current = current; self.next = next }
}

/// Turns a SharedState into the frames a WidgetKit timeline shows. Pure, so it is testable off-device.
public enum LyricTimeline {
    /// WidgetKit fires entries late by tens to hundreds of ms; lead by this much.
    public static let schedulingBias: TimeInterval = 0.15
    /// Timelines past a few hundred entries have been seen to stop updating entirely.
    public static let maxEntries = 400

    public static func frames(for s: SharedState, now: Date) -> [LyricFrame] {
        guard !s.lines.isEmpty else { return [LyricFrame(date: now, current: s.title, next: s.artist)] }

        if !s.isPlaying {
            return [frame(index(at: s.position, in: s.lines), in: s, date: now)]
        }

        let t0 = s.anchor.addingTimeInterval(s.offset - schedulingBias)
        let current = index(at: now.timeIntervalSince(t0), in: s.lines)
        var out = [frame(current, in: s, date: now)]
        for i in ((current ?? -1) + 1)..<s.lines.count where out.count < maxEntries {
            out.append(frame(i, in: s, date: t0.addingTimeInterval(s.lines[i].t)))
        }
        return out
    }

    /// Index of the last line at or before `t`; nil before the first line.
    public static func index(at t: TimeInterval, in lines: [SharedState.Line]) -> Int? {
        lines.lastIndex { $0.t <= t }
    }

    static func frame(_ i: Int?, in s: SharedState, date: Date) -> LyricFrame {
        guard let i else { return LyricFrame(date: date, current: s.title, next: s.lines.first?.text) }
        let next = i + 1 < s.lines.count ? s.lines[i + 1].text : nil
        return LyricFrame(date: date, current: s.lines[i].text, next: next)
    }
}
