#!/usr/bin/env bash
# Fetches the Kokoro model weights + voice style vectors for the spike.
#
# The KokoroSwift package expects an MLX-format model (see its KokoroTestApp).
# Sources are not hard-coded because the exact artifact you need depends on the
# pinned KokoroSwift version. Set the URLs explicitly, then this script verifies
# checksums (if provided) and drops files where the app reads them.
#
# Usage:
#   MODEL_URL=...  VOICES_URL=...  ./scripts/download_models.sh
# Optional integrity checks:
#   MODEL_SHA256=...  VOICES_SHA256=...
#
# Candidate sources to evaluate:
#   - hexgrad/Kokoro-82M (HF)            : original weights (PyTorch; may need MLX conversion)
#   - onnx-community/Kokoro-82M-v1.0-ONNX: kokoro-v1.0.onnx (~80-86 MB quantized) + voices-v1.0.bin
#   - mlalma/kokoro-ios KokoroTestApp    : the MLX model file the Swift package loads
set -euo pipefail

DEST="${DEST:-spike/Models}"
mkdir -p "$DEST"

require_url() {
  if [ -z "${!1:-}" ]; then
    echo "ERROR: set $1 (see header for candidate sources)." >&2
    exit 1
  fi
}

verify() {
  local file="$1" expected="$2"
  [ -z "$expected" ] && return 0
  local actual
  actual="$(shasum -a 256 "$file" | awk '{print $1}')"
  if [ "$actual" != "$expected" ]; then
    echo "ERROR: checksum mismatch for $file" >&2
    echo "  expected $expected" >&2
    echo "  actual   $actual" >&2
    exit 1
  fi
  echo "  checksum OK"
}

fetch() {
  local url="$1" out="$2" sha="$3"
  echo "Downloading $(basename "$out")…"
  curl -fL --retry 4 --retry-delay 2 -o "$out" "$url"
  verify "$out" "$sha"
}

require_url MODEL_URL
require_url VOICES_URL

fetch "$MODEL_URL"  "$DEST/kokoro.mlx"        "${MODEL_SHA256:-}"
fetch "$VOICES_URL" "$DEST/voices-v1.0.bin"   "${VOICES_SHA256:-}"

echo "Done. Files in $DEST/ (gitignored)."
ls -lh "$DEST"
