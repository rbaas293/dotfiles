#!/bin/bash
# Install zsh. macOS uses Homebrew. Debian and Ubuntu use apt-get.
set -euo pipefail

if [ "$(id -u)" -eq 0 ]; then
  as_root() { "$@"; }
else
  as_root() { sudo "$@"; }
fi

if [ "$(uname -s)" = "Darwin" ]; then
  command -v brew >/dev/null 2>&1 || {
    echo "Homebrew is required. See https://brew.sh" >&2
    exit 1
  }
  brew install zsh
elif [ -r /etc/os-release ]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  case "${ID:-}:${ID_LIKE:-}" in
    *debian*|*ubuntu*)
      as_root apt-get update
      as_root apt-get install -y zsh
      ;;
    *)
      echo "Install zsh with your package manager, then re-run." >&2
      exit 1
      ;;
  esac
else
  echo "Install zsh with your package manager, then re-run." >&2
  exit 1
fi
