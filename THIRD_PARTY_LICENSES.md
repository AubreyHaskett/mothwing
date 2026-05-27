# Third-Party Licenses

MothWing's on-device TTS is built from the following open-source components.
This file is the engine-spike inventory; keep it current and surface its
contents in an in-app "Licenses" screen for the shipping app.

| Component | Role | License | Commercial use | Source |
|---|---|---|---|---|
| Kokoro-82M | TTS model weights | Apache-2.0 | Yes | https://huggingface.co/hexgrad/Kokoro-82M |
| KokoroSwift (kokoro-ios) | MLX inference in Swift | MIT | Yes | https://github.com/mlalma/kokoro-ios |
| MisakiSwift | English G2P (no espeak) | Apache-2.0 | Yes | https://github.com/mlalma/MisakiSwift |
| mlx-swift | Tensor runtime | MIT | Yes | https://github.com/ml-explore/mlx-swift |

## Licensing risk: avoid espeak-ng

espeak-ng is **GPLv3** and would impose copyleft on a paid, closed-source app.
The product spec explicitly requires an espeak-free English G2P. MisakiSwift
satisfies this: it uses Apple's Natural Language framework + pronunciation
dictionaries + a small neural fallback for out-of-vocabulary words, with **no
espeak dependency**.

Action item during the spike: confirm that the *resolved* dependency graph
(KokoroSwift -> its G2P) does not transitively pull espeak-ng. KokoroSwift
exposes `g2p: .misaki`; verify that path is espeak-free as resolved.
