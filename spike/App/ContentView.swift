import SwiftUI
import AVFoundation
import SpikeKit
#if !targetEnvironment(simulator)
import SpikeEngine
#endif

@MainActor
final class SpikeModel: ObservableObject {
    enum EngineKind: String, CaseIterable, Identifiable {
        case stub = "Stub"
        case apple = "Apple TTS"
        #if !targetEnvironment(simulator)
        case kokoro = "Kokoro-MLX"
        #endif
        var id: String { rawValue }
    }

    /// Common Kokoro v1.0 voices. 'a' prefix = American, 'b' = British.
    static let voiceOptions = [
        "af_heart", "af_bella", "af_nicole",
        "am_adam", "am_michael",
        "bf_emma", "bf_isabella",
        "bm_george", "bm_lewis",
    ]

    @Published var text = BenchmarkCorpus.text
    @Published var engineKind: EngineKind = .stub
    @Published var voice = "af_heart"
    @Published var status = "Idle."
    @Published var summary = ""
    @Published var csvURL: URL?
    @Published var isRunning = false

    private var player: AVAudioPlayer?

    private func makeEngine() -> TTSEngine {
        switch engineKind {
        case .stub:
            return StubTTSEngine()
        case .apple:
            return AppleTTSEngine()
        #if !targetEnvironment(simulator)
        case .kokoro:
            return KokoroTTSEngine(
                modelPath: Self.resolve("kokoro-v1_0", "safetensors"),
                voicesPath: Self.resolve("voices", "npz")
            )
        #endif
        }
    }

    /// Prefer a file bundled in the app target; fall back to Documents/Models so
    /// you can push files onto a device without rebuilding.
    private static func resolve(_ name: String, _ ext: String) -> URL {
        if let bundled = Bundle.main.url(forResource: name, withExtension: ext) {
            return bundled
        }
        return modelsDirectory().appendingPathComponent("\(name).\(ext)")
    }

    func runBenchmark() {
        guard !isRunning else { return }
        isRunning = true
        status = "Preparing engine…"
        summary = ""
        csvURL = nil

        let engine = makeEngine()
        let device = DeviceInfo.modelIdentifier()
        let voice = voice
        let text = text

        Task {
            do {
                let runner = BenchmarkRunner(engine: engine)
                self.status = "Generating \(TextSegmenter.sentences(in: text).count) sentences…"
                let (report, audio, index) = try await runner.run(
                    text: text, voice: voice, deviceIdentifier: device
                )
                let cache = try AudioCache.write(
                    audio: audio, index: index,
                    named: "benchmark", in: Self.cacheDirectory()
                )
                let csv = report.csv()
                let csvURL = Self.cacheDirectory().appendingPathComponent("benchmark.csv")
                try csv.data(using: .utf8)?.write(to: csvURL, options: .atomic)

                self.summary = """
                Device: \(report.deviceIdentifier)
                Engine: \(report.engineName)  Voice: \(report.voice)
                Cold start to first audio: \(String(format: "%.2f", report.coldStartFirstAudio)) s
                Mean RTF: \(String(format: "%.2f", report.meanRTF))  (p90 \(String(format: "%.2f", report.p90RTF)))
                Throttle (2nd half / 1st half): \(String(format: "%.2f", report.throttleRatio))
                Total audio: \(String(format: "%.1f", report.totalAudio)) s in \(String(format: "%.1f", report.totalGeneration)) s
                Verdict: \(report.meanRTF < 1 ? "FASTER than real time ✅" : "SLOWER than real time ⚠️")
                """
                self.csvURL = csvURL
                self.status = "Done. Cached: \(cache.audioURL.lastPathComponent)"
                self.play(url: cache.audioURL)
            } catch {
                self.status = "Error: \(error)"
            }
            self.isRunning = false
        }
    }

    private func play(url: URL) {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            let p = try AVAudioPlayer(contentsOf: url)
            p.prepareToPlay()
            p.volume = 1.0
            self.player = p
            p.play()
        } catch {
            status = "Playback error: \(error)"
        }
    }

    private static func modelsDirectory() -> URL {
        documents().appendingPathComponent("Models", isDirectory: true)
    }
    private static func cacheDirectory() -> URL {
        documents().appendingPathComponent("Cache", isDirectory: true)
    }
    private static func documents() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}

struct ContentView: View {
    @StateObject private var model = SpikeModel()

    var body: some View {
        NavigationStack {
            Form {
                Section("Engine") {
                    Picker("Engine", selection: $model.engineKind) {
                        ForEach(SpikeModel.EngineKind.allCases) { Text($0.rawValue).tag($0) }
                    }
                    Picker("Voice", selection: $model.voice) {
                        ForEach(SpikeModel.voiceOptions, id: \.self) { Text($0).tag($0) }
                    }
                }

                Section("Text") {
                    TextEditor(text: $model.text)
                        .frame(minHeight: 140)
                        .font(.system(.body, design: .serif))
                }

                Section {
                    Button(model.isRunning ? "Running…" : "Run Benchmark") {
                        model.runBenchmark()
                    }
                    .disabled(model.isRunning)

                    if let csvURL = model.csvURL {
                        ShareLink("Export CSV", item: csvURL)
                    }
                }

                Section("Result") {
                    Text(model.status).font(.footnote).foregroundStyle(.secondary)
                    if !model.summary.isEmpty {
                        Text(model.summary).font(.system(.footnote, design: .monospaced))
                    }
                }
            }
            .navigationTitle("MothWing Spike")
        }
    }
}
