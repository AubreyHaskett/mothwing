#!/usr/bin/env bash
# Fetches the MLX Kokoro model + voices the spike's KokoroSwift path expects:
#   - kokoro-v1_0.safetensors  (~600 MB, full precision; stored via Git LFS)
#   - voices.npz               (~15 MB; committed directly)
#
# These are the exact artifacts KokoroSwift 1.0.9 loads (NpyzReader for voices,
# safetensors for weights), sourced from the companion KokoroTestApp. The
# Hugging Face hexgrad weights are a different format (.pth) and are NOT a drop-in
# replacement here.
#
# Default: shallow-clone KokoroTestApp (with Git LFS) and copy Resources/.
# Override with explicit URLs if you host the files yourself:
#   MODEL_URL=... VOICES_URL=... ./scripts/download_models.sh
set -euo pipefail

DEST="${DEST:-spike/Models}"
REPO="${TESTAPP_REPO:-https://github.com/mlalma/KokoroTestApp.git}"
mkdir -p "$DEST"

fetch_url() {
  echo "Downloading $(basename "$2")…"
  curl -fL --retry 4 --retry-delay 2 -o "$2" "$1"
}

if [ -n "${MODEL_URL:-}" ] && [ -n "${VOICES_URL:-}" ]; then
  fetch_url "$MODEL_URL"  "$DEST/kokoro-v1_0.safetensors"
  fetch_url "$VOICES_URL" "$DEST/voices.npz"
else
  if ! command -v git-lfs >/dev/null 2>&1; then
    echo "ERROR: git-lfs is required to pull the ~600 MB safetensors." >&2
    echo "Install it (e.g. 'brew install git-lfs && git lfs install') or set MODEL_URL/VOICES_URL." >&2
    exit 1
  fi
  TMP="$(mktemp -d)"
  trap 'rm -rf "$TMP"' EXIT
  echo "Cloning $REPO (with LFS) …"
  GIT_LFS_SKIP_SMUDGE=0 git clone --depth 1 "$REPO" "$TMP/app"
  git -C "$TMP/app" lfs pull
  cp "$TMP/app/Resources/kokoro-v1_0.safetensors" "$DEST/"
  cp "$TMP/app/Resources/voices.npz" "$DEST/"
fi

echo "Done. Files in $DEST/ (gitignored):"
ls -lh "$DEST"
echo
echo "Next: either add both files to the MothWingSpike app target in Xcode"
echo "(so Bundle.main finds them), or push them to the device's Documents/Models."
