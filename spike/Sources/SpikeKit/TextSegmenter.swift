import Foundation

/// Deliberately simple sentence splitter for the spike's benchmark corpus.
/// The real app will use NLTokenizer; here we avoid an Apple-only dependency so
/// SpikeKit stays cross-platform testable. Handles common abbreviations so the
/// per-sentence timing buckets are sensible.
public enum TextSegmenter {
    private static let abbreviations: Set<String> = [
        "mr", "mrs", "ms", "dr", "st", "jr", "sr", "vs", "etc", "no", "vol",
    ]

    public static func sentences(in text: String) -> [String] {
        var result: [String] = []
        var current = ""

        let scalars = Array(text)
        var i = 0
        while i < scalars.count {
            let ch = scalars[i]
            current.append(ch)

            if ch == "." || ch == "!" || ch == "?" {
                let next = i + 1 < scalars.count ? scalars[i + 1] : " "
                let boundary = next == " " || next == "\n" || next == "\r" || i + 1 == scalars.count
                if boundary && !endsWithAbbreviation(current) {
                    let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty { result.append(trimmed) }
                    current = ""
                }
            }
            i += 1
        }

        let tail = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tail.isEmpty { result.append(tail) }
        return result
    }

    private static func endsWithAbbreviation(_ s: String) -> Bool {
        let words = s.split { $0 == " " || $0 == "\n" }
        guard let last = words.last else { return false }
        let word = last.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        return abbreviations.contains(word)
    }
}
