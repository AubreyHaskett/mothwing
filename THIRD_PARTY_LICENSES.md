# Third-Party Licenses

MothWing's on-device TTS is built from the following open-source components.
This file is the engine-spike inventory; keep it current and surface its
contents in an in-app "Licenses" screen for the shipping app.

Resolved against KokoroSwift **1.0.9**.

| Component | Role | License | Commercial use | Source |
|---|---|---|---|---|
| Kokoro-82M | TTS model weights | Apache-2.0 | Yes | https://huggingface.co/hexgrad/Kokoro-82M |
| KokoroSwift (kokoro-ios) | MLX inference in Swift | MIT | Yes | https://github.com/mlalma/kokoro-ios |
| MisakiSwift | English G2P (no espeak) | Apache-2.0 | Yes | https://github.com/mlalma/MisakiSwift |
| MLXUtilsLibrary | .npz/.safetensors loading | Apache-2.0 | Yes | https://github.com/mlalma/MLXUtilsLibrary |
| mlx-swift | Tensor runtime | MIT | Yes | https://github.com/ml-explore/mlx-swift |
| ZIPFoundation | npz unzip (via MLXUtilsLibrary) | MIT | Yes | https://github.com/weichsel/ZIPFoundation |

## Licensing risk: avoid espeak-ng — satisfied

espeak-ng is **GPLv3** and would impose copyleft on a paid, closed-source app.
The product spec requires an espeak-free English G2P, and the resolved graph
honors this:

- KokoroSwift 1.0.9 defaults to `g2p: .misaki` and its `eSpeakNGSwift` dependency
  and `eSpeakNGLib` product are **commented out** in its `Package.swift` — so the
  espeak path is not even linked.
- MisakiSwift does English G2P with Apple's Natural Language framework +
  pronunciation dictionaries + a small neural fallback, **no espeak**.

Re-verify this if you bump the KokoroSwift pin (an upstream change could
re-enable the espeak dependency).
