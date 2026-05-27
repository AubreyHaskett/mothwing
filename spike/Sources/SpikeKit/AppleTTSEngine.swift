import Foundation
import AVFoundation

/// Uses Apple's built-in AVSpeechSynthesizer to produce real speech.
/// Not a Kokoro benchmark — just lets you hear actual text on the simulator.
public final class AppleTTSEngine: @unchecked Sendable, TTSEngine {
    public let name = "Apple TTS"
    public let availableVoices = ["af_heart", "am_adam", "bf_emma", "bm_george"]

    private let outputRate = 24_000
    private let synthesizer = AVSpeechSynthesizer()

    public init() {}

    public func prepare() async throws {}

    public func synthesize(text: String, voice: String) async throws -> SynthesisResult {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: voice.hasPrefix("b") ? "en-GB" : "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate

        let samples = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[Float], Error>) in
            var allSamples = [Float]()
            var resumed = false
            let outputRate = self.outputRate
            let synth = self.synthesizer

            synth.write(utterance) { buffer in
                guard !resumed else { return }

                guard let pcm = buffer as? AVAudioPCMBuffer, pcm.frameLength > 0,
                      let floatData = pcm.floatChannelData else {
                    resumed = true
                    continuation.resume(returning: allSamples)
                    return
                }

                let frameCount = Int(pcm.frameLength)
                let inputRate = pcm.format.sampleRate

                if abs(inputRate - Double(outputRate)) < 1 {
                    let ptr = UnsafeBufferPointer(start: floatData[0], count: frameCount)
                    allSamples.append(contentsOf: ptr)
                } else {
                    let ratio = inputRate / Double(outputRate)
                    let outCount = Int(Double(frameCount) / ratio)
                    for i in 0..<outCount {
                        let srcIdx = min(Int(Double(i) * ratio), frameCount - 1)
                        allSamples.append(floatData[0][srcIdx])
                    }
                }
            }
        }

        guard !samples.isEmpty else {
            throw TTSEngineError.synthesisFailed("Apple TTS produced no audio (\(text.prefix(30))...)")
        }
        return SynthesisResult(samples: samples, sampleRate: outputRate)
    }
}
