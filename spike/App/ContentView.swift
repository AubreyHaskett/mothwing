import SwiftUI
import AVFoundation
import SpikeKit
import SpikeEngine

@MainActor
final class SpikeModel: ObservableObject {
    enum EngineKind: String, CaseIterable, Identifiable {
        case stub = "Stub"
        case kokoro = "Kokoro-MLX"
        var id: String { rawValue }
    }

    @Published var text = BenchmarkCorpus.text
    @Published var engineKind: EngineKind = .stub
    @Published var voice = "af_heart"
    @Published var status = "Idle."
    @Published var summary = ""
    @Published var csvURL: URL?
    @Published var isRunning = false

    private var player: AVAudioPlayer?

    var voices: [String] { makeEngine().availableVoices }

    private func makeEngine() -> TTSEngine {
        switch engineKind {
        case .stub:
            return StubTTSEngine()
        case .kokoro:
            let models = Self.modelsDirectory()
            return KokoroTTSEngine(
                modelPath: models.appendingPathComponent("kokoro.mlx"),
                voicesPath: models.appendingPathComponent("voices-v1.0.bin"),
                voices: ["af_heart", "am_adam", "bf_emma", "bm_george"]
            )
        }
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
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
            player = try AVAudioPlayer(contentsOf: url)
            player?.play()
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
                        ForEach(model.voices, id: \.self) { Text($0).tag($0) }
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
