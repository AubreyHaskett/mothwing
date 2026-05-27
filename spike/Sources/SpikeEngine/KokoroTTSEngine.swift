import Foundation
import SpikeKit
import KokoroSwift
import MLX

/// On-device Kokoro engine via the KokoroSwift (MLX) package.
///
/// Two integration points below could NOT be verified from the scaffolding
/// environment (no macOS/Xcode/MLX). Confirm both against the pinned KokoroSwift
/// version using its companion "KokoroTestApp" before trusting any numbers:
///   (1) how voice style vectors are loaded into `MLXArray`
///   (2) the concrete type `generateAudio` returns and how to read its samples
/// These are marked `TODO(verify)`.
public final class KokoroTTSEngine: TTSEngine, @unchecked Sendable {
    public let name = "Kokoro-MLX"

    private let modelPath: URL
    private let voicesPath: URL
    private let voices: [String]
    private var tts: KokoroTTS?
    private var voiceEmbeddings: [String: MLXArray] = [:]

    public var availableVoices: [String] { voices }

    public init(modelPath: URL, voicesPath: URL, voices: [String]) {
        self.modelPath = modelPath
        self.voicesPath = voicesPath
        self.voices = voices
    }

    public func prepare() async throws {
        guard FileManager.default.fileExists(atPath: modelPath.path) else {
            throw TTSEngineError.modelMissing(modelPath)
        }
        let engine = KokoroTTS(modelPath: modelPath, g2p: .misaki)

        // TODO(verify): load each voice's style vector from `voicesPath` into an
        // MLXArray. KokoroTestApp shows the exact layout of voices-v1.0; replace
        // this stub load with that logic.
        for voice in voices {
            voiceEmbeddings[voice] = try Self.loadVoiceEmbedding(named: voice, from: voicesPath)
        }
        self.tts = engine
    }

    public func synthesize(text: String, voice: String) async throws -> SynthesisResult {
        guard let tts else { throw TTSEngineError.notPrepared }
        guard let embedding = voiceEmbeddings[voice] else { throw TTSEngineError.unknownVoice(voice) }

        let buffer = try tts.generateAudio(voice: embedding, language: .enUS, text: text)

        // TODO(verify): map KokoroSwift's return type to [Float] @ 24 kHz.
        // If it returns AVAudioPCMBuffer, read floatChannelData; if [Float]/MLXArray,
        // convert accordingly. Update `samples`/`sampleRate` to match.
        let samples = Self.floatSamples(from: buffer)
        return SynthesisResult(samples: samples, sampleRate: 24_000)
    }

    // MARK: - Integration shims (replace with real KokoroTestApp logic)

    private static func loadVoiceEmbedding(named: String, from voicesPath: URL) throws -> MLXArray {
        fatalError("Wire voice loading from \(voicesPath.lastPathComponent) — see SPIKE.md step 4.")
    }

    private static func floatSamples(from buffer: Any) -> [Float] {
        fatalError("Map KokoroSwift audio buffer to [Float] — see SPIKE.md step 4.")
    }
}
