import Foundation

public actor BenchmarkRunner {
    private let engine: TTSEngine

    public init(engine: TTSEngine) {
        self.engine = engine
    }

    /// Runs a cold-start measurement: prepares the engine, then synthesizes the
    /// corpus sentence-by-sentence and records per-sentence timing plus the
    /// concatenated audio (so the caller can encode + cache it).
    public func run(text: String, voice: String, deviceIdentifier: String)
        async throws -> (report: BenchmarkReport, audio: SynthesisResult, index: SentenceIndex)
    {
        let prepStart = Date()
        try await engine.prepare()
        let prepareTime = Date().timeIntervalSince(prepStart)

        let sentences = TextSegmenter.sentences(in: text)
        var metrics: [SentenceMetric] = []
        var allSamples: [Float] = []
        var indexEntries: [SentenceIndexEntry] = []
        var sampleRate = 24_000
        var cursor: TimeInterval = 0

        for (i, sentence) in sentences.enumerated() {
            let start = Date()
            let result = try await engine.synthesize(text: sentence, voice: voice)
            let genTime = Date().timeIntervalSince(start)
            sampleRate = result.sampleRate

            metrics.append(SentenceMetric(
                index: i,
                charCount: sentence.count,
                audioDuration: result.duration,
                generationTime: genTime
            ))

            let end = cursor + result.duration
            indexEntries.append(SentenceIndexEntry(index: i, text: sentence, start: cursor, end: end))
            cursor = end
            allSamples.append(contentsOf: result.samples)
        }

        let report = BenchmarkReport(
            engineName: engine.name,
            deviceIdentifier: deviceIdentifier,
            voice: voice,
            prepareTime: prepareTime,
            sentences: metrics
        )
        let audio = SynthesisResult(samples: allSamples, sampleRate: sampleRate)
        let index = SentenceIndex(sampleRate: sampleRate, entries: indexEntries)
        return (report, audio, index)
    }
}
