import Foundation
import SpikeKit
import KokoroSwift
import MLX
import MLXUtilsLibrary

/// On-device Kokoro engine via the KokoroSwift (MLX) package, pinned to 1.0.9.
/// Mirrors the usage proven in kokoro-ios's KokoroTestApp:
///   - voices load from a `.npz` into `[String: MLXArray]` (keys like "af_heart.npy")
///   - `generateAudio` returns `([Float], [MToken]?)`; the `[Float]` is 24 kHz PCM
///   - language is chosen by voice-name prefix ('a' = American, else British)
/// If you bump the KokoroSwift pin, re-check these against the new tag.
public final class KokoroTTSEngine: TTSEngine, @unchecked Sendable {
    public let name = "Kokoro-MLX"

    private let modelPath: URL
    private let voicesPath: URL
    private var tts: KokoroTTS?
    private var voices: [String: MLXArray] = [:]
    private var voiceNames: [String] = []

    public var availableVoices: [String] { voiceNames }

    /// - Parameters:
    ///   - modelPath: kokoro-v1_0.safetensors
    ///   - voicesPath: voices.npz
    public init(modelPath: URL, voicesPath: URL) {
        self.modelPath = modelPath
        self.voicesPath = voicesPath
    }

    public func prepare() async throws {
        guard FileManager.default.fileExists(atPath: modelPath.path) else {
            throw TTSEngineError.modelMissing(modelPath)
        }
        guard FileManager.default.fileExists(atPath: voicesPath.path) else {
            throw TTSEngineError.modelMissing(voicesPath)
        }

        guard let loaded = NpyzReader.read(fileFromPath: voicesPath), !loaded.isEmpty else {
            throw TTSEngineError.synthesisFailed("could not read voices from \(voicesPath.lastPathComponent)")
        }
        voices = loaded
        voiceNames = loaded.keys.map { String($0.split(separator: ".")[0]) }.sorted()

        tts = KokoroTTS(modelPath: modelPath)
    }

    public func synthesize(text: String, voice: String) async throws -> SynthesisResult {
        guard let tts else { throw TTSEngineError.notPrepared }
        guard let style = voices[voice + ".npy"] else { throw TTSEngineError.unknownVoice(voice) }

        let language: Language = (voice.first == "a") ? .enUS : .enGB
        let (samples, _) = try tts.generateAudio(voice: style, language: language, text: text)
        return SynthesisResult(samples: samples, sampleRate: KokoroTTS.Constants.samplingRate)
    }
}
