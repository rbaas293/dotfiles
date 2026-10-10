#!/bin/bash
# Compatibility wrapper. The installer lives in scripts/setup-zsh.sh.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
exec "$ROOT/scripts/setup-zsh.sh" "$@"
