#!/usr/bin/env bash
# Install zsh, tmux, and vim configs on macOS or Debian/Ubuntu.
#
#   ./setup.sh [--yes] [--no-chsh] [--source DIR]
#   ./setup.sh --pack                 # online install, then build/dotfiles-offline.tar.gz
#   ./setup.sh --zipapp               # online install, then build/dotfiles.pyz
#   ./setup.sh --offline --source DIR # air-gapped install from an extracted archive
#   TMUXAI_API_TOKEN=TOKEN ./setup.sh --with-tmuxai
#   ./setup.sh --with-tmuxai --token-file /path/to/token
#
# --source skips the SSH clone and uses that checkout. CI passes the
# GitHub workspace. On a machine of yours, clone with:
#   git clone git@github.com:rbaas293/dotfiles.git ~/.dotfiles
#
# --offline never calls curl, git, brew, or apt. zsh, tmux, and vim must
# already be installed. .zprofile is not installed.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=scripts/common.sh
source "$SCRIPT_DIR/scripts/common.sh"

REPO_URL="git@github.com:rbaas293/dotfiles.git"
DO_PACK=0
DO_ZIPAPP=0
WITH_TMUXAI=0
TMUXAI_ARGS=()

usage() {
  sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --yes|-y) DOTFILES_ASSUME_YES=1 ;;
    --no-chsh) DOTFILES_NO_CHSH=1 ;;
    --dry-run) DOTFILES_DRY_RUN=1 ;;
    --offline) DOTFILES_OFFLINE=1 ;;
    --pack) DO_PACK=1 ;;
    --zipapp) DO_ZIPAPP=1 ;;
    --with-tmuxai) WITH_TMUXAI=1 ;;
    --source)
      [ "$#" -ge 2 ] || die "--source needs a directory"
      DOTFILES_SOURCE=$2
      shift
      ;;
    --token)
      die "Do not pass the API token on the command line. Set TMUXAI_API_TOKEN or use --token-file."
      ;;
    --token-file|--provider|--model|--base-url)
      [ "$#" -ge 2 ] || die "$1 needs a value"
      TMUXAI_ARGS+=("$1" "$2")
      shift
      ;;
    --anthropic)
      TMUXAI_ARGS+=("$1")
      ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown option: $1" ;;
  esac
  shift
done

if [ "$DOTFILES_OFFLINE" -eq 1 ] && { [ "$DO_PACK" -eq 1 ] || [ "$DO_ZIPAPP" -eq 1 ]; }; then
  die "--pack and --zipapp need a network. Run them on an online machine."
fi
if [ "$WITH_TMUXAI" -eq 1 ] && [ "$DOTFILES_OFFLINE" -eq 1 ]; then
  die "TmuxAI is not part of the offline archive."
fi

export DOTFILES_SOURCE DOTFILES_OFFLINE DOTFILES_DRY_RUN DOTFILES_ASSUME_YES \
  DOTFILES_NO_CHSH DOTFILES_SKIP_PACKAGES DOTFILES_PERSIST

resolve_source() {
  if [ -n "$DOTFILES_SOURCE" ]; then
    [ -d "$DOTFILES_SOURCE" ] || die "No such directory: $DOTFILES_SOURCE"
    DOTFILES_SOURCE=$(abspath "$DOTFILES_SOURCE")
  elif [ -f "$SCRIPT_DIR/.zshrc" ]; then
    DOTFILES_SOURCE=$SCRIPT_DIR
  elif [ -f "$HOME/.dotfiles/.zshrc" ]; then
    DOTFILES_SOURCE="$HOME/.dotfiles"
    if [ "$DOTFILES_OFFLINE" -eq 0 ] && [ "$DOTFILES_DRY_RUN" -eq 0 ] && [ -d "$DOTFILES_SOURCE/.git" ]; then
      info "Updating $DOTFILES_SOURCE"
      git -C "$DOTFILES_SOURCE" pull --ff-only
    fi
  elif [ "$DOTFILES_OFFLINE" -eq 1 ]; then
    die "Offline mode needs --source pointing at the extracted archive."
  elif [ "$DOTFILES_DRY_RUN" -eq 1 ]; then
    info "would clone $REPO_URL to $HOME/.dotfiles"
    return 0
  else
    info "Cloning $REPO_URL to $HOME/.dotfiles"
    git clone --depth=1 "$REPO_URL" "$HOME/.dotfiles"
    DOTFILES_SOURCE="$HOME/.dotfiles"
  fi
  export DOTFILES_SOURCE
  [ -f "$DOTFILES_SOURCE/.zshrc" ] || die "$DOTFILES_SOURCE has no .zshrc"
  [ -f "$DOTFILES_SOURCE/.zshenv" ] || die "$DOTFILES_SOURCE has no .zshenv"
  [ -f "$DOTFILES_SOURCE/.tmux.conf" ] || die "$DOTFILES_SOURCE has no .tmux.conf"
  [ -f "$DOTFILES_SOURCE/.vimrc" ] || die "$DOTFILES_SOURCE has no .vimrc"
}

# Clone the Plugin entries in vimrc. Vim's :silent !git clone fills its output
# pipe and then waits forever, which is what stuck the CI jobs. A missing or
# private repo is skipped instead of asking for credentials.
clone_vim_plugins() {
  local vimrc=$1 bundle="$HOME/.vim/bundle" spec name url
  mkdir -p "$bundle"
  while IFS= read -r spec; do
    [ -n "$spec" ] || continue
    name=${spec##*/}
    name=${name%.git}
    url="https://github.com/${spec}.git"
    if [ -d "$bundle/$name" ]; then
      ok "Vim plugin $spec already present"
      continue
    fi
    info "Cloning Vim plugin $spec"
    if ! GIT_TERMINAL_PROMPT=0 git clone --depth=1 "$url" "$bundle/$name"; then
      rm -rf "${bundle:?}/${name:?}"
      warn "Could not clone $spec"
    fi
  done <<EOF
$(awk -F "'" '/^[[:space:]]*Plugin / { print $2 }' "$vimrc")
EOF
}

install_vim() {
  local vimrc
  vimrc=$(config_link_source .vimrc)
  link_file "$vimrc" "$HOME/.vimrc"
  if [ "$DOTFILES_OFFLINE" -eq 1 ]; then
    [ -d "$DOTFILES_SOURCE/cache/vim-bundle" ] || die "cache/vim-bundle is missing. Re-run ./setup.sh --pack on an online machine."
    info "Installing Vim plugins from the offline cache"
    mkdir -p "$HOME/.vim"
    copy_tree "$DOTFILES_SOURCE/cache/vim-bundle" "$HOME/.vim/bundle"
    return 0
  fi
  if [ "$DOTFILES_DRY_RUN" -eq 1 ] || [ "$DOTFILES_SKIP_PACKAGES" -eq 1 ]; then
    info "Skipping Vim plugin clones"
    return 0
  fi
  info "Installing Vim plugins"
  clone_vim_plugins "$vimrc"
  ok "Vim plugins installed"
}

stage_payload() {
  local stage=$1
  if [ "$DOTFILES_DRY_RUN" -eq 1 ]; then
    info "would stage $stage"
    return 0
  fi
  [ -d "$HOME/.oh-my-zsh" ] || die "Oh My Zsh is not installed yet. Run ./setup.sh without --offline first."
  [ -d "$HOME/.vim/bundle" ] || die "Vim plugins are not installed yet. Run ./setup.sh without --offline first."
  rm -rf "$stage"
  mkdir -p "$stage/scripts" "$stage/cache"
  cp -a "$SCRIPT_DIR/setup.sh" "$stage/setup.sh"
  cp -a "$SCRIPT_DIR/scripts/." "$stage/scripts/"
  local name
  for name in .zshrc .zshenv .tmux.conf .vimrc; do
    cp -a "$DOTFILES_SOURCE/$name" "$stage/$name"
  done
  copy_tree "$HOME/.oh-my-zsh" "$stage/cache/oh-my-zsh"
  copy_tree "$HOME/.vim/bundle" "$stage/cache/vim-bundle"
  chmod 755 "$stage/setup.sh"
  chmod 755 "$stage/scripts/"*.sh
}

write_checksum() {
  local file=$1
  local base
  base=$(basename "$file")
  if have sha256sum; then
    (cd "$(dirname "$file")" && sha256sum "$base" > "$base.sha256")
  else
    (cd "$(dirname "$file")" && shasum -a 256 "$base" > "$base.sha256")
  fi
}

pack_archive() {
  local build="$SCRIPT_DIR/build"
  local stage="$build/dotfiles-offline"
  local archive="$build/dotfiles-offline.tar.gz"
  info "Packing offline archive"
  if [ "$DOTFILES_DRY_RUN" -eq 1 ]; then
    info "would write $archive"
    return 0
  fi
  mkdir -p "$build"
  stage_payload "$stage"
  tar -C "$build" -czf "$archive" dotfiles-offline
  write_checksum "$archive"
  ok "Wrote $archive"
}

build_zipapp() {
  local build="$SCRIPT_DIR/build"
  local stage="$build/zipapp-src"
  local app="$build/dotfiles.pyz"
  info "Building zipapp"
  if [ "$DOTFILES_DRY_RUN" -eq 1 ]; then
    info "would write $app"
    return 0
  fi
  have python3 || die "python3 is required to build the zipapp."
  mkdir -p "$build"
  stage_payload "$stage"
  cp -a "$SCRIPT_DIR/scripts/zipapp_main.py" "$stage/__main__.py"
  rm -f "$app"
  python3 -m zipapp "$stage" -p "/usr/bin/env python3" -o "$app"
  chmod 755 "$app"
  write_checksum "$app"
  ok "Wrote $app"
}

resolve_source

if [ "$DOTFILES_OFFLINE" -eq 1 ]; then
  require_offline_tools
else
  ensure_packages
fi

bash "$SCRIPT_DIR/scripts/setup-zsh.sh"
bash "$SCRIPT_DIR/scripts/setup-tmuxai.sh" --tmux-only
install_vim

if [ -e "$HOME/.zprofile" ]; then
  ok "Left existing .zprofile unchanged"
else
  ok ".zprofile was not installed"
fi

if [ "$WITH_TMUXAI" -eq 1 ]; then
  if [ "${#TMUXAI_ARGS[@]}" -eq 0 ]; then
    bash "$SCRIPT_DIR/scripts/setup-tmuxai.sh"
  else
    bash "$SCRIPT_DIR/scripts/setup-tmuxai.sh" "${TMUXAI_ARGS[@]}"
  fi
fi

if [ "$DO_PACK" -eq 1 ]; then
  pack_archive
fi
if [ "$DO_ZIPAPP" -eq 1 ]; then
  build_zipapp
fi

info "Done. Open a new terminal, or run: exec zsh"
