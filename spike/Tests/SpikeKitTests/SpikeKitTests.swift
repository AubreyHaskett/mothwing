import XCTest
@testable import SpikeKit

final class SpikeKitTests: XCTestCase {
    func testSentenceSegmentationKeepsAbbreviationsIntact() {
        let text = "My dear Mr. Bennet went to Netherfield. He liked it!"
        let sentences = TextSegmenter.sentences(in: text)
        XCTAssertEqual(sentences.count, 2)
        XCTAssertTrue(sentences[0].contains("Mr. Bennet"))
    }

    func testRealTimeFactorMath() {
        let m = SentenceMetric(index: 0, charCount: 10, audioDuration: 2.0, generationTime: 1.0)
        XCTAssertEqual(m.realTimeFactor, 0.5, accuracy: 1e-9)
    }

    func testReportAggregatesColdStartAndMeanRTF() {
        let sentences = [
            SentenceMetric(index: 0, charCount: 10, audioDuration: 2.0, generationTime: 1.0),
            SentenceMetric(index: 1, charCount: 10, audioDuration: 2.0, generationTime: 3.0),
        ]
        let report = BenchmarkReport(
            engineName: "Stub", deviceIdentifier: "test", voice: "af_heart",
            prepareTime: 0.5, sentences: sentences
        )
        XCTAssertEqual(report.coldStartFirstAudio, 1.5, accuracy: 1e-9)
        XCTAssertEqual(report.meanRTF, 1.0, accuracy: 1e-9) // (1+3)/(2+2)
        XCTAssertTrue(report.csv().contains("mean_rtf"))
    }

    func testSentenceIndexLookup() {
        let index = SentenceIndex(sampleRate: 24_000, entries: [
            SentenceIndexEntry(index: 0, text: "a", start: 0, end: 1.0),
            SentenceIndexEntry(index: 1, text: "b", start: 1.0, end: 2.5),
        ])
        XCTAssertEqual(index.entry(at: 1.2)?.index, 1)
        XCTAssertEqual(index.entry(at: 0.0)?.index, 0)
    }

    func testStubEngineProducesAudioAndBenchmarkRuns() async throws {
        let runner = BenchmarkRunner(engine: StubTTSEngine())
        let (report, audio, index) = try await runner.run(
            text: "Hello there. This is a test sentence! And a third one?",
            voice: "af_heart",
            deviceIdentifier: "test"
        )
        XCTAssertEqual(report.sentences.count, 3)
        XCTAssertEqual(index.entries.count, 3)
        XCTAssertGreaterThan(audio.samples.count, 0)
        XCTAssertEqual(audio.sampleRate, 24_000)
    }
}
