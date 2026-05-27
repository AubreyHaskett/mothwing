import Foundation

/// A model-free engine so the whole pipeline (UI -> benchmark -> cache -> CSV)
/// runs in the simulator before any weights exist. It does NOT measure Kokoro
/// performance — it fakes plausible durations so the harness can be exercised.
public struct StubTTSEngine: TTSEngine {
    public let name = "Stub"
    public let availableVoices = ["af_heart", "am_adam", "bf_emma", "bm_george"]

    private let sampleRate = 24_000
    private let secondsPerChar: Double
    private let pretendRTF: Double

    /// - Parameters:
    ///   - secondsPerChar: rough speaking rate used to fake audio duration.
    ///   - pretendRTF: faked generation/audio ratio (< 1 = faster than realtime).
    public init(secondsPerChar: Double = 0.06, pretendRTF: Double = 0.4) {
        self.secondsPerChar = secondsPerChar
        self.pretendRTF = pretendRTF
    }

    public func prepare() async throws {
        try await Task.sleep(nanoseconds: 200_000_000)
    }

    public func synthesize(text: String, voice: String) async throws -> SynthesisResult {
        guard availableVoices.contains(voice) else { throw TTSEngineError.unknownVoice(voice) }

        let audioSeconds = max(0.2, Double(text.count) * secondsPerChar)
        let frames = Int(audioSeconds * Double(sampleRate))

        // Simulate generation cost proportional to audio length.
        try await Task.sleep(nanoseconds: UInt64(audioSeconds * pretendRTF * 1_000_000_000))

        // 220 Hz tone so "Play" produces something audible.
        var samples = [Float](repeating: 0, count: frames)
        let twoPiF = 2.0 * Double.pi * 220.0 / Double(sampleRate)
        for n in 0..<frames {
            samples[n] = Float(0.2 * sin(twoPiF * Double(n)))
        }
        return SynthesisResult(samples: samples, sampleRate: sampleRate)
    }
}
