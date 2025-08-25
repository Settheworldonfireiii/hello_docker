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
exec "$@"
