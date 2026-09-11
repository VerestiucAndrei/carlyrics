import Foundation

/// No debugger and no console over the air: keep a ring buffer on screen and a file in Documents
/// (visible in the Files app via UIFileSharingEnabled).
@MainActor
final class Log: ObservableObject {
    static let shared = Log()
    @Published private(set) var lines: [String] = []
    private let file = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("log.txt")

    func add(_ s: String) {
        let line = "\(Date().formatted(date: .omitted, time: .standard)) \(s)"
        lines.append(line)
        if lines.count > 200 { lines.removeFirst() }
        if let h = try? FileHandle(forWritingTo: file) {
            h.seekToEndOfFile(); h.write(Data((line + "\n").utf8)); try? h.close()
        } else {
            try? Data((line + "\n").utf8).write(to: file)
        }
    }
}
