import Foundation

/// Sentence -> time mapping that makes tap-to-seek and follow-along highlighting
/// work on cached playback. Persisted alongside the compressed audio.
public struct SentenceIndexEntry: Codable, Sendable {
    public let index: Int
    public let text: String
    public let start: TimeInterval
    public let end: TimeInterval

    public init(index: Int, text: String, start: TimeInterval, end: TimeInterval) {
        self.index = index
        self.text = text
        self.start = start
        self.end = end
    }
}

public struct SentenceIndex: Codable, Sendable {
    public let sampleRate: Int
    public let entries: [SentenceIndexEntry]

    public init(sampleRate: Int, entries: [SentenceIndexEntry]) {
        self.sampleRate = sampleRate
        self.entries = entries
    }

    /// Which sentence is being spoken at `time` — the highlight lookup.
    public func entry(at time: TimeInterval) -> SentenceIndexEntry? {
        entries.first { time >= $0.start && time < $0.end } ?? entries.last
    }

    public func write(to url: URL) throws {
        let data = try JSONEncoder().encode(self)
        try data.write(to: url, options: .atomic)
    }

    public static func read(from url: URL) throws -> SentenceIndex {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(SentenceIndex.self, from: data)
    }
}
