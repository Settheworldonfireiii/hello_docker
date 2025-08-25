#!/bin/bash
set -e

# Set environment variables with defaults
export REGION="${REGION:-us-south}"
export BUCKET="${BUCKET:-ossgpt}"
export OUTDIR="${OUTDIR:-bucket_download}"

# Run the AWS S3 sync command
aws s3 sync "s3://${BUCKET}/" "$OUTDIR" \
#     --endpoint-url "https://s3.${REGION}.cloud-object-storage.appdomain.cloud" \
#     --no-sign-request

# Execute the main command (passed as arguments to this script)
exec "$@"
