#!/usr/bin/env bash
# Shared helpers for setup.sh and scripts/setup-*.sh.
# Shell scripts source this file. It does not run an install by itself.

: "${DOTFILES_OFFLINE:=0}"
: "${DOTFILES_DRY_RUN:=0}"
: "${DOTFILES_ASSUME_YES:=0}"
: "${DOTFILES_NO_CHSH:=0}"
: "${DOTFILES_SKIP_PACKAGES:=0}"
: "${DOTFILES_SOURCE:=}"
: "${DOTFILES_PERSIST:=}"

info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m  ok\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m  !\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

have() { command -v "$1" >/dev/null 2>&1; }

run() {
  if [ "$DOTFILES_DRY_RUN" -eq 1 ]; then
    info "would run: $*"
    return 0
  fi
  "$@"
}

is_darwin() { [ "$(uname -s)" = "Darwin" ]; }

is_debian() {
  [ -r /etc/os-release ] || return 1
  # shellcheck disable=SC1091
  . /etc/os-release
  case "${ID:-}:${ID_LIKE:-}" in
    *debian*|*ubuntu*) return 0 ;;
    *) return 1 ;;
  esac
}

as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  else
    sudo "$@"
  fi
}

# Install zsh, tmux, vim, git, and curl when they are missing.
ensure_packages() {
  if [ "$DOTFILES_OFFLINE" -eq 1 ] || [ "$DOTFILES_SKIP_PACKAGES" -eq 1 ] || [ "$DOTFILES_DRY_RUN" -eq 1 ]; then
    return 0
  fi
  local missing=() tool
  for tool in zsh tmux vim git curl; do
    if ! have "$tool"; then
      missing+=("$tool")
    fi
  done
  if [ "${#missing[@]}" -eq 0 ]; then
    ok "zsh, tmux, vim, git, and curl are present"
    return 0
  fi
  if is_darwin; then
    have brew || die "Homebrew is required to install: ${missing[*]}. See https://brew.sh"
    info "Installing ${missing[*]} with Homebrew"
    brew install "${missing[@]}"
  elif is_debian; then
    info "Installing ${missing[*]} with apt-get"
    as_root apt-get update
    as_root apt-get install -y "${missing[@]}"
  else
    die "Missing ${missing[*]}. Install them, then re-run."
  fi
}

# Offline installs refuse to fetch these. They must already be on PATH.
require_offline_tools() {
  local tool
  for tool in zsh tmux vim; do
    have "$tool" || die "$tool is not installed. Install it from an internal mirror, then re-run --offline."
  done
  ok "zsh, tmux, and vim are present"
}

backup_path() {
  printf '%s.backup.%s\n' "$1" "$(date +%Y%m%d%H%M%S)"
}

# Point dest at src. An existing different file is moved aside first.
link_file() {
  local src=$1 dest=$2
  if [ "$DOTFILES_DRY_RUN" -eq 1 ]; then
    info "would link $dest -> $src"
    return 0
  fi
  [ -e "$src" ] || die "missing $src"
  if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
    ok "$dest already links to $src"
    return 0
  fi
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    local backup
    backup=$(backup_path "$dest")
    mv "$dest" "$backup"
    ok "backed up $dest -> $backup"
  fi
  ln -s "$src" "$dest"
  ok "linked $dest -> $src"
}

# Zipapp installs copy configs out of the temp extract so the links survive.
config_link_source() {
  local name=$1
  local src="$DOTFILES_SOURCE/$name"
  [ -f "$src" ] || die "missing $src"
  if [ -z "$DOTFILES_PERSIST" ]; then
    printf '%s\n' "$src"
    return 0
  fi
  if [ "$DOTFILES_DRY_RUN" -eq 1 ]; then
    printf '%s\n' "$DOTFILES_PERSIST/$name"
    return 0
  fi
  mkdir -p "$DOTFILES_PERSIST"
  cp -a "$src" "$DOTFILES_PERSIST/$name"
  printf '%s\n' "$DOTFILES_PERSIST/$name"
}

copy_tree() {
  local src=$1 dest=$2
  [ -d "$src" ] || die "missing $src"
  if [ "$DOTFILES_DRY_RUN" -eq 1 ]; then
    info "would copy $src -> $dest"
    return 0
  fi
  rm -rf "$dest"
  mkdir -p "$dest"
  tar -C "$src" --exclude .git -cf - . | tar -C "$dest" -xf -
}

abspath() {
  (cd "$1" && pwd)
}
