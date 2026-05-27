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

## Status: written, not yet compiled

Generated in a Linux container with no macOS/Xcode/MLX, so nothing here has been
compiled or run. The Kokoro wiring is **complete** (no stubs) — coded against the
real KokoroSwift 1.0.9 API verified from source — but expect to shake out minor
issues on a real Mac. Layout:

- **`spike/Sources/SpikeKit`** — harness with no external code dependencies
  (engine protocol, benchmark runner, metrics/CSV, sentence index, AAC cache,
  stub engine). Unit-tested with `swift test`. (SPM still resolves the whole
  package graph, so that command needs network + a Swift 6.2 toolchain.)
- **`spike/Sources/SpikeEngine`** — real Kokoro wiring via `KokoroSwift` (MLX),
  voices via `MLXUtilsLibrary` `NpyzReader`. Pinned to KokoroSwift 1.0.9.
- **`spike/App`** — SwiftUI harness assembled into an app by `project.yml`.

## Stack

| Layer | Choice | License |
|---|---|---|
| UI / shell | Swift + SwiftUI, iOS 18+ | — |
| Inference | KokoroSwift (MLX) 1.0.9 | MIT |
| G2P | misaki via KokoroSwift (`g2p: .misaki`), espeak-free | Apache-2.0 |
| Voices loader | MLXUtilsLibrary `NpyzReader` | Apache-2.0 |
| Model | Kokoro-82M v1.0, `kokoro-v1_0.safetensors` | Apache-2.0 |

iOS 18 floor still covers every A13–A15 device (iPhone 11 / SE2 and up).

**Toolchain:** KokoroSwift and its deps ship Swift 6.2 manifests, so you need a
recent Xcode (Swift 6.2 toolchain) to resolve/build this package — including
`swift test`, which resolves the full graph even though it only compiles SpikeKit.

**Model size:** the MLX path uses the **full-precision `kokoro-v1_0.safetensors`
(~600 MB)**, not the ~86 MB quantized ONNX the product spec assumed. That's fine
for answering the speed question; shrinking the download (quantization) is a
separate follow-up before shipping.

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
In Xcode, resolve packages. KokoroSwift is pinned to 1.0.9 in `spike/Package.swift`.
Confirm the resolved graph does **not** link espeak-ng (see THIRD_PARTY_LICENSES.md;
KokoroSwift 1.0.9 has its eSpeak dependency commented out).

### 4. Get the model + voices
```
./scripts/download_models.sh        # needs git-lfs; clones KokoroTestApp Resources
```
This fetches `kokoro-v1_0.safetensors` (~600 MB, Git LFS) and `voices.npz` into
`spike/Models/` (gitignored). To self-host instead:
`MODEL_URL=... VOICES_URL=... ./scripts/download_models.sh`.

Then make the app find them, either:
- **Bundle (simplest):** drag both files into the `MothWingSpike` target in Xcode
  ("Copy items if needed", added to the app's Resources). `Bundle.main` resolves
  them automatically. Do **not** commit them (they're gitignored).
- **Documents:** push both into the app's `Documents/Models/` on the device.

The app's file resolver prefers the bundle and falls back to `Documents/Models`.

### 5. Benchmark on hardware (the actual experiment)
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
