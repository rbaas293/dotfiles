#!/usr/bin/env bash
# Install Oh My Zsh, the two external plugins, and link .zshrc and .zshenv.
#
#   ./scripts/setup-zsh.sh [--yes] [--no-chsh] [--source DIR] [--offline] [--dry-run]
#
# Config files come from --source, or from the repo that contains this script.
# --offline copies cache/oh-my-zsh and does not use the network.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck disable=SC1091
source "$SCRIPT_DIR/common.sh"

OMZ_INSTALL_URL="https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh"

usage() {
  sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --yes|-y) DOTFILES_ASSUME_YES=1 ;;
    --no-chsh) DOTFILES_NO_CHSH=1 ;;
    --offline) DOTFILES_OFFLINE=1 ;;
    --dry-run) DOTFILES_DRY_RUN=1 ;;
    --verbose|-v|--debug|-d) ;;
    --source)
      [ "$#" -ge 2 ] || die "--source needs a directory"
      DOTFILES_SOURCE=$2
      shift
      ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown option: $1" ;;
  esac
  shift
done

if [ -z "$DOTFILES_SOURCE" ]; then
  if [ -f "$SCRIPT_DIR/../.zshrc" ]; then
    DOTFILES_SOURCE=$(abspath "$SCRIPT_DIR/..")
  else
    die "Pass --source with the dotfiles checkout."
  fi
else
  DOTFILES_SOURCE=$(abspath "$DOTFILES_SOURCE")
fi

link_zsh_configs() {
  link_file "$(config_link_source .zshrc)" "$HOME/.zshrc"
  link_file "$(config_link_source .zshenv)" "$HOME/.zshenv"
}

maybe_chsh() {
  local zsh_path
  zsh_path=$(command -v zsh) || die "zsh is not on PATH"
  if [ "${SHELL:-}" = "$zsh_path" ]; then
    ok "zsh is already the login shell"
    return 0
  fi
  if [ "$DOTFILES_NO_CHSH" -eq 1 ]; then
    warn "Leaving the login shell unchanged. Later: chsh -s $zsh_path"
    return 0
  fi
  if [ "$DOTFILES_DRY_RUN" -eq 1 ]; then
    info "would set the login shell to $zsh_path"
    return 0
  fi
  local change=1
  if [ "$DOTFILES_ASSUME_YES" -ne 1 ]; then
    if [ ! -r /dev/tty ]; then
      warn "No terminal for the shell prompt. Later: chsh -s $zsh_path"
      return 0
    fi
    printf 'Make %s your login shell? [y/N] ' "$zsh_path"
    local reply
    read -r reply </dev/tty || reply=""
    case "$reply" in
      y|Y|yes|YES) change=1 ;;
      *) change=0 ;;
    esac
  fi
  if [ "$change" -ne 1 ]; then
    warn "Login shell unchanged. Later: chsh -s $zsh_path"
    return 0
  fi
  if ! grep -qx "$zsh_path" /etc/shells 2>/dev/null; then
    info "Adding $zsh_path to /etc/shells"
    echo "$zsh_path" | as_root tee -a /etc/shells >/dev/null
  fi
  if ! chsh -s "$zsh_path"; then
    as_root chsh -s "$zsh_path" "${USER:-$(id -un)}"
  fi
  ok "Login shell set to $zsh_path"
}

install_offline() {
  require_offline_tools
  [ -d "$DOTFILES_SOURCE/cache/oh-my-zsh" ] || die "cache/oh-my-zsh is missing. Re-run ./setup.sh --pack on an online machine."
  info "Installing Oh My Zsh from the offline cache"
  copy_tree "$DOTFILES_SOURCE/cache/oh-my-zsh" "$HOME/.oh-my-zsh"
  link_zsh_configs
  maybe_chsh
}

clone_or_update() {
  local url=$1 dest=$2
  if [ -d "$dest/.git" ]; then
    git -C "$dest" pull --ff-only
    ok "updated $(basename "$dest")"
  else
    rm -rf "$dest"
    git clone --depth=1 "$url" "$dest"
    ok "cloned $(basename "$dest")"
  fi
}

install_online() {
  ensure_packages
  have zsh || die "zsh is required"
  have git || die "git is required"
  have curl || die "curl is required"

  if [ -d "$HOME/.oh-my-zsh" ]; then
    ok "Oh My Zsh already installed"
  elif [ "$DOTFILES_DRY_RUN" -eq 1 ]; then
    info "would install Oh My Zsh"
  elif [ "$DOTFILES_SKIP_PACKAGES" -eq 1 ]; then
    warn "Skipping Oh My Zsh install"
  else
    info "Installing Oh My Zsh"
    local installer
    installer=$(mktemp)
    curl -fsSL "$OMZ_INSTALL_URL" -o "$installer"
    # Ignore a ZSH value inherited from the parent shell. It points at the
    # real home even when this install is using a different HOME.
    env ZSH="$HOME/.oh-my-zsh" RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh "$installer" --unattended
    rm -f "$installer"
    ok "Oh My Zsh installed"
  fi

  if [ "$DOTFILES_DRY_RUN" -eq 1 ] || [ "$DOTFILES_SKIP_PACKAGES" -eq 1 ]; then
    info "Skipping plugin clones"
  else
    local custom="$HOME/.oh-my-zsh/custom"
    mkdir -p "$custom/plugins"
    info "Installing zsh plugins"
    clone_or_update https://github.com/zsh-users/zsh-syntax-highlighting.git "$custom/plugins/zsh-syntax-highlighting"
    clone_or_update https://github.com/zsh-users/zsh-autosuggestions.git "$custom/plugins/zsh-autosuggestions"
  fi

  link_zsh_configs
  maybe_chsh
}

if [ "$DOTFILES_OFFLINE" -eq 1 ]; then
  install_offline
else
  install_online
fi
info "zsh config installed from $DOTFILES_SOURCE"
