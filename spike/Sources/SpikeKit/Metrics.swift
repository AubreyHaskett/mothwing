import Foundation

public struct SentenceMetric: Sendable {
    public let index: Int
    public let charCount: Int
    public let audioDuration: TimeInterval
    public let generationTime: TimeInterval

    public init(index: Int, charCount: Int, audioDuration: TimeInterval, generationTime: TimeInterval) {
        self.index = index
        self.charCount = charCount
        self.audioDuration = audioDuration
        self.generationTime = generationTime
    }

    /// generation time / audio duration. < 1.0 means the engine outruns playback.
    public var realTimeFactor: Double {
        guard audioDuration > 0 else { return .infinity }
        return generationTime / audioDuration
    }
}

public struct BenchmarkReport: Sendable {
    public let engineName: String
    public let deviceIdentifier: String
    public let voice: String
    /// Model load / warm-up cost, measured before the first synthesis.
    public let prepareTime: TimeInterval
    public let sentences: [SentenceMetric]

    public init(engineName: String, deviceIdentifier: String, voice: String,
                prepareTime: TimeInterval, sentences: [SentenceMetric]) {
        self.engineName = engineName
        self.deviceIdentifier = deviceIdentifier
        self.voice = voice
        self.prepareTime = prepareTime
        self.sentences = sentences
    }

    public var totalAudio: TimeInterval { sentences.reduce(0) { $0 + $1.audioDuration } }
    public var totalGeneration: TimeInterval { sentences.reduce(0) { $0 + $1.generationTime } }

    /// Cold-start time to first audible sentence = model load + first synthesis.
    public var coldStartFirstAudio: TimeInterval {
        prepareTime + (sentences.first?.generationTime ?? 0)
    }

    public var meanRTF: Double {
        guard totalAudio > 0 else { return .infinity }
        return totalGeneration / totalAudio
    }

    public var p90RTF: Double { percentileRTF(0.90) }

    /// Drift across the run — if late sentences are slower than early ones, the
    /// device is throttling. This is the real risk for long listening sessions.
    public var throttleRatio: Double {
        guard sentences.count >= 4 else { return 1 }
        let half = sentences.count / 2
        let firstHalf = Array(sentences[..<half])
        let secondHalf = Array(sentences[half...])
        let a = meanRTF(of: firstHalf)
        let b = meanRTF(of: secondHalf)
        guard a > 0 else { return 1 }
        return b / a
    }

    private func meanRTF(of group: [SentenceMetric]) -> Double {
        let audio = group.reduce(0) { $0 + $1.audioDuration }
        let gen = group.reduce(0) { $0 + $1.generationTime }
        guard audio > 0 else { return .infinity }
        return gen / audio
    }

    private func percentileRTF(_ p: Double) -> Double {
        let sorted = sentences.map(\.realTimeFactor).sorted()
        guard !sorted.isEmpty else { return .infinity }
        let idx = min(sorted.count - 1, Int((Double(sorted.count) * p).rounded(.down)))
        return sorted[idx]
    }

    public func csv() -> String {
        var lines = ["sentence_index,char_count,audio_s,gen_s,rtf"]
        for m in sentences {
            lines.append("\(m.index),\(m.charCount),\(fmt(m.audioDuration)),\(fmt(m.generationTime)),\(fmt(m.realTimeFactor))")
        }
        lines.append("")
        lines.append("# engine,\(engineName)")
        lines.append("# device,\(deviceIdentifier)")
        lines.append("# voice,\(voice)")
        lines.append("# prepare_s,\(fmt(prepareTime))")
        lines.append("# cold_start_first_audio_s,\(fmt(coldStartFirstAudio))")
        lines.append("# total_audio_s,\(fmt(totalAudio))")
        lines.append("# total_generation_s,\(fmt(totalGeneration))")
        lines.append("# mean_rtf,\(fmt(meanRTF))")
        lines.append("# p90_rtf,\(fmt(p90RTF))")
        lines.append("# throttle_ratio_2ndhalf_over_1sthalf,\(fmt(throttleRatio))")
        return lines.joined(separator: "\n")
    }

    private func fmt(_ v: Double) -> String { String(format: "%.4f", v) }
}
