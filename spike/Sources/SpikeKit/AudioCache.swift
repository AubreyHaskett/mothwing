import Foundation
import AVFoundation

/// Encodes generated PCM to compressed AAC (.m4a) and stores the sentence index
/// beside it — the spike's stand-in for the per-chapter cache the real app needs.
/// Re-reading proves cached playback is instant and that tap-to-seek timing holds.
public enum AudioCache {
    public struct Entry {
        public let audioURL: URL
        public let indexURL: URL
    }

    public static func write(audio: SynthesisResult, index: SentenceIndex,
                             named name: String, in directory: URL) throws -> Entry {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let audioURL = directory.appendingPathComponent("\(name).m4a")
        let indexURL = directory.appendingPathComponent("\(name).index.json")

        try encodeAAC(samples: audio.samples, sampleRate: audio.sampleRate, to: audioURL)
        try index.write(to: indexURL)
        return Entry(audioURL: audioURL, indexURL: indexURL)
    }

    static func encodeAAC(samples: [Float], sampleRate: Int, to url: URL) throws {
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }

        guard let sourceFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Double(sampleRate),
            channels: 1,
            interleaved: false
        ) else {
            throw TTSEngineError.synthesisFailed("invalid audio format")
        }

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]

        let file = try AVAudioFile(forWriting: url, settings: settings)

        // Write in chunks so very long audio doesn't allocate one giant buffer.
        let chunk = 24_000
        var offset = 0
        while offset < samples.count {
            let count = min(chunk, samples.count - offset)
            guard let buffer = AVAudioPCMBuffer(
                pcmFormat: sourceFormat,
                frameCapacity: AVAudioFrameCount(count)
            ) else {
                throw TTSEngineError.synthesisFailed("could not allocate PCM buffer")
            }
            buffer.frameLength = AVAudioFrameCount(count)
            samples.withUnsafeBufferPointer { ptr in
                buffer.floatChannelData![0].update(from: ptr.baseAddress! + offset, count: count)
            }
            try file.write(from: buffer)
            offset += count
        }
    }
}
