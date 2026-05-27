import Foundation

/// Mono PCM produced by a TTS engine. Kokoro emits 24 kHz float samples in [-1, 1].
public struct SynthesisResult: Sendable {
    public let samples: [Float]
    public let sampleRate: Int

    public init(samples: [Float], sampleRate: Int) {
        self.samples = samples
        self.sampleRate = sampleRate
    }

    public var duration: TimeInterval {
        guard sampleRate > 0 else { return 0 }
        return Double(samples.count) / Double(sampleRate)
    }
}

/// The one interface the benchmark, cache, and UI depend on. Swap MLX / CoreML /
/// Stub implementations behind it without touching the rest of the harness.
public protocol TTSEngine: Sendable {
    var name: String { get }
    var availableVoices: [String] { get }

    /// Load weights / warm up. Time this separately — it is the cold-start cost.
    func prepare() async throws

    func synthesize(text: String, voice: String) async throws -> SynthesisResult
}

public enum TTSEngineError: Error, CustomStringConvertible {
    case notPrepared
    case unknownVoice(String)
    case modelMissing(URL)
    case synthesisFailed(String)

    public var description: String {
        switch self {
        case .notPrepared: return "Engine.prepare() was not called."
        case .unknownVoice(let v): return "Unknown voice: \(v)"
        case .modelMissing(let url): return "Model file not found at \(url.path)"
        case .synthesisFailed(let m): return "Synthesis failed: \(m)"
        }
    }
}
