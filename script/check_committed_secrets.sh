#!/usr/bin/env bash
# Guard against committed secrets (audit M1 regression guard).
#
# Fails if a secret-shaped hex run (16+ hex chars) appears in any tracked file.
# 16+ catches Rails master keys (32 hex) and secret_key_base (64+ hex).
#
# Excluded from the scan:
#   - Gemfile.lock and *.sum: checksums, not credentials.
#   - diagrams/ and docs/diagrams/: SVG path data contains hex-like runs.
#
# A SHA-256 digest written as `sha256:` followed by exactly 64 hex chars
# (e.g. the OpenAPI source hash in clients/ts/index.ts) is an integrity hash,
# not a credential, so the lookahead exempts it. Any other length after
# `sha256:` still fails, and a secret on the same line is still caught.
#
# A real RAILS_MASTER_KEY shipped in .env.example once (audit M1, 2026-09-25)
# and decrypted config/credentials.yml.enc.
#
# Run from the repository root (CI and bin/ci both do).
# Exit: 0 clean; 1 secret-shaped string found; anything else means git grep
# itself failed, and the guard fails closed.

set -uo pipefail

pattern='(?<![0-9a-fA-F])(?!(?<=sha256:)[0-9a-fA-F]{64}(?![0-9a-fA-F]))[0-9a-fA-F]{16,}'

git grep -InP "$pattern" -- . ':!Gemfile.lock' ':!*.sum' ':!diagrams/*' ':!docs/diagrams/*'
status=$?

case "$status" in
  0)
    echo "::error::Secret-shaped hex string committed. Tracked files must use placeholders; real values belong only in the uncommitted .env (audit M1)."
    exit 1
    ;;
  1)
    echo "No secret-shaped hex strings found in tracked files."
    ;;
  *)
    echo "::error::Secret guard could not run (git grep exit $status)."
    exit "$status"
    ;;
esac
