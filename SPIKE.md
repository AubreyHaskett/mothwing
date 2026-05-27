# MothWing Engine Spike

Goal: decide **go / no-go on on-device Kokoro** before building the real app.
The one question that matters: on a **mid-range / older iPhone (A13–A15)**, does
Kokoro generate audio **faster than real time** (RTF < 1) and stay that way over
a long session? If yes, we pre-generate ahead of playback. If no, we must
pre-bake whole books and redesign the "preparing audio" UX.

Prior art says this is promising: `kokoro-ios` reports ~3.3× faster than real
time on an iPhone 13 Pro (A15). This spike confirms it on the devices we
actually care about and measures the things a single warm-up number hides
(cold start, thermal throttling, battery).

## Why this is a scaffold, not finished code

It was generated in a Linux container with no macOS/Xcode/MLX, so it could not
be compiled or run here. Split:

- **`spike/Sources/SpikeKit`** — dependency-free harness (engine protocol,
  benchmark runner, metrics/CSV, sentence index, AAC cache, stub engine).
  Builds + unit-tests on your Mac with `swift test`.
- **`spike/Sources/SpikeEngine`** — the real Kokoro wiring via `KokoroSwift`.
  Has **two `TODO(verify)` integration points** (see step 4) that need the
  KokoroTestApp to finalize.
- **`spike/App`** — SwiftUI harness assembled into an app by `project.yml`.

## Stack

| Layer | Choice | License |
|---|---|---|
| UI / shell | Swift + SwiftUI, iOS 18+ | — |
| Inference | KokoroSwift (MLX) | MIT |
| G2P | misaki via KokoroSwift (`g2p: .misaki`), espeak-free | Apache-2.0 |
| Model | Kokoro-82M v1.0 (MLX) | Apache-2.0 |

iOS 18 floor still covers every A13–A15 device (iPhone 11 / SE2 and up).

## Run procedure

### 1. Validate the harness with no model (simulator or Mac)
```
cd spike && swift test
```
Then run the app with the **Stub** engine selected to confirm the full pipeline
(generate → cache to .m4a → sentence index → CSV export → playback) works. The
stub fakes timings; it does not measure Kokoro.

### 2. Generate the Xcode project
```
brew install xcodegen      # if needed
xcodegen generate          # from repo root -> MothWingSpike.xcodeproj
open MothWingSpike.xcodeproj
```
No xcodegen? Create a new iOS App in Xcode (iOS 18), add `spike` as a local
package, link products `SpikeKit` + `SpikeEngine`, and add `spike/App/*.swift`
to the app target. Set `UIBackgroundModes = [audio]`.

### 3. Resolve dependencies and confirm the license graph
In Xcode, resolve packages. Then verify the resolved graph does **not** pull in
espeak-ng (see THIRD_PARTY_LICENSES.md). Pin `kokoro-ios` and `mlx-swift` to
specific commits/tags in `spike/Package.swift` before recording numbers.

### 4. Wire the two Kokoro integration points
In `spike/Sources/SpikeEngine/KokoroTTSEngine.swift`, using the KokoroTestApp
from the kokoro-ios repo as reference:
- `loadVoiceEmbedding(named:from:)` — load each voice's style vector (`MLXArray`)
  from `voices-v1.0.bin`.
- `floatSamples(from:)` — convert `generateAudio(...)`'s return value to
  `[Float]` at 24 kHz (adjust the assumed sample rate if it differs).

### 5. Get the model
```
MODEL_URL=...  VOICES_URL=...  ./scripts/download_models.sh
```
See the script header for candidate sources. Files land in `spike/Models/`
(gitignored). The app reads `Models/kokoro.mlx` + `Models/voices-v1.0.bin` from
the app's Documents dir — copy them onto the device/simulator, or adjust the
paths in `ContentView.swift`.

### 6. Benchmark on hardware (the actual experiment)
Run on a **physical A13–A15 device** (release build). Select the **Kokoro**
engine and tap **Run Benchmark**. Export the CSV. Then:
- Repeat warm (run again without relaunch) vs cold (relaunch first).
- Run a **long** pass (paste several chapters) and watch `throttle_ratio` — this
  is the long-session thermal signal a one-shot test misses.
- Note battery drain over ~20–30 min of continuous generation.

## What gets measured (CSV + on-screen summary)

| Metric | Meaning | Target |
|---|---|---|
| `mean_rtf` | generation ÷ audio over the run | **< 1.0** |
| `p90_rtf` | worst-case per-sentence RTF | < 1.0 ideally |
| `cold_start_first_audio_s` | model load + first sentence | drives "preparing…" UX |
| `throttle_ratio` | 2nd-half RTF ÷ 1st-half RTF | **≈ 1.0** (no throttle) |
| battery / hr | drain during continuous gen | qualitative |
| G2P quality | names/numbers/abbreviations correct? | acceptable, espeak-free |

## Go / no-go rubric

- **GO** — `mean_rtf < 1` AND `throttle_ratio ≲ 1.3` on the mid-range device, with
  acceptable G2P quality. Build the app around pre-generating ahead of playback.
- **CONDITIONAL** — fast warm but throttles on long runs, or the oldest target is
  borderline. Ship with a buffer/pre-generation lead and a device floor; consider
  CoreML/ANE (more power-efficient) as a follow-up — slot a second engine behind
  the `TTSEngine` protocol.
- **NO-GO** — `mean_rtf ≥ 1` on mid-range. Pre-bake whole books up front; redesign
  onboarding/import around a longer one-time "preparing your book" wait.

## After the spike

If GO, design the real native architecture around a background-aware
generation + caching service (pre-generates next chapter while current plays),
then build the MVP per the spec's order: first-run → paste/share import → EPUB →
Reader/Player with synchronized highlighting.
