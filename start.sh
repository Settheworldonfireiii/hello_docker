#!/usr/bin/env bash
set -euo pipefail

log() { printf "[entrypoint] %s\n" "$*" >&2; }

# Defaults
MODEL_DIR="${MODEL_DIR:-/models}"
COS_ENDPOINT="${COS_ENDPOINT:-https://s3.us-south.cloud-object-storage.appdomain.cloud}"
COS_REGION="${COS_REGION:-us-south}"
COS_BUCKET="${COS_BUCKET:-}"
COS_PREFIX="${COS_PREFIX:-}"
COS_NO_SIGN_REQUEST="${COS_NO_SIGN_REQUEST:-}"

# Make sure target dir exists and is writable
mkdir -p "${MODEL_DIR}"
# If running as non-root, you may need to chown. With root, skip this.
# chown -R "$(id -u)":"$(id -g)" "${MODEL_DIR}"

# Build aws s3 sync args
AWS_ARGS=(s3 sync)
SRC="s3://${COS_BUCKET}/${COS_PREFIX}"
DST="${MODEL_DIR}"

# Endpoint + region
AWS_ARGS+=("${SRC}" "${DST}" \
  --endpoint-url "${COS_ENDPOINT}" \
  --region "${COS_REGION}" \
  --only-show-errors)

# Public bucket?
if [[ -n "${COS_NO_SIGN_REQUEST}" ]]; then
  AWS_ARGS+=(--no-sign-request)
fi

# Idempotency: don’t re-download if we already did once.
# Customize this logic as you like.
MARKER="${MODEL_DIR}/.synced.ok"

if [[ ! -f "${MARKER}" ]]; then
  log "Syncing from ${SRC} -> ${DST}"
  # Optional retries (backoff)
  for attempt in 1 2 3; do
    if aws "${AWS_ARGS[@]}"; then
      touch "${MARKER}"
      log "Sync complete."
      break
    fi
    log "Sync failed (attempt ${attempt}); retrying in $((attempt*10))s..."
    sleep $((attempt*10))
  done
  if [[ ! -f "${MARKER}" ]]; then
    log "Sync failed after retries."
    exit 1
  fi
else
  log "Found ${MARKER}; skipping sync."
fi

# If you want to ensure the files are there, list them
ls -lh "${MODEL_DIR}" || true

# Hand off to the actual container command (interactive shell or your app)
# --- SGLang serve (GGUF) ---
# Pick the first shard and let SGLang discover the rest
PRIMARY_SHARD="$(ls -1 "${MODEL_DIR}"/*-00001-of-*.gguf | head -n1)"

# Sensible defaults (override via env if you like)
export SGL_PORT="${SGL_PORT:-30000}"
export SGL_HOST="${SGL_HOST:-0.0.0.0}"
export SGL_TP="${SGL_TP:-1}"                       # tensor parallel degree
export SGL_MEM_FRAC="${SGL_MEM_FRAC:-0.85}"        # reduce if you hit OOM
export SGL_EXTRA_ARGS="${SGL_EXTRA_ARGS:-}"         # freeform flags

# Launch SGLang’s OpenAI-compatible server for GGUF
python3 -m sglang.launch_server \
  --model-path "${PRIMARY_SHARD}" \
  --load-format gguf \
  --host "${SGL_HOST}" \
  --port "${SGL_PORT}" \
  --tp "${SGL_TP}" \
  --mem-fraction-static "${SGL_MEM_FRAC}" \
  ${SGL_EXTRA_ARGS}

# If the line above succeeds, it never returns; if it exits, we fall through:

exec "$@"
