#!/usr/bin/env bash
# Install tmux config from this repo and, when a token is provided, TmuxAI.
#
#   TMUXAI_API_TOKEN=TOKEN ./scripts/setup-tmuxai.sh
#   ./scripts/setup-tmuxai.sh --token-file /path/to/token
#
#   --token-file PATH   Read the API token from a file. It is not a command argument.
#   --provider NAME     openrouter (default), openai, azure, or gemini
#   --model ID          default: anthropic/claude-haiku-4.5
#   --base-url URL      optional OpenAI-compatible endpoint
#   --anthropic         provider=openai, Anthropic base URL, Claude Sonnet model
#   --yes, -y           overwrite an existing TmuxAI config without asking
#   --source DIR        dotfiles checkout (default: this repo)
#   --tmux-only         link .tmux.conf and skip TmuxAI
#   --dry-run

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck disable=SC1091
source "$SCRIPT_DIR/common.sh"

TMUXAI_INSTALL_URL="https://get.tmuxai.dev"
TMUXAI_CONFIG_DIR="${HOME}/.config/tmuxai"
TMUXAI_CONFIG="${TMUXAI_CONFIG_DIR}/config.yaml"
ANTHROPIC_BASE_URL="https://api.anthropic.com/v1"

TOKEN="${TMUXAI_API_TOKEN:-}"
PROVIDER="openrouter"
MODEL="anthropic/claude-haiku-4.5"
BASE_URL=""
MODEL_NAME="primary"
USE_ANTHROPIC=0
MODEL_SET=0
TMUX_ONLY=0

usage() {
  sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'
}

# grep splits on newlines, so it cannot see them. A trailing marker keeps
# tr's control characters from being stripped by command substitution.
contains_control() {
  local marked
  marked=$(printf '%s' "$1" | LC_ALL=C tr -cd '[:cntrl:]'; printf x)
  [ "$marked" != "x" ]
}

read_token_file() {
  local path=$1 raw
  [ -f "$path" ] || die "No token file at $path"
  raw=$(cat "$path")
  TOKEN=${raw%$'\n'}
  TOKEN=${TOKEN%$'\r'}
  if contains_control "$TOKEN"; then
    die "Token file contains a newline or other control character."
  fi
  [ -n "$TOKEN" ] || die "Token file is empty."
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --token)
      die "Do not pass the API token on the command line. Set TMUXAI_API_TOKEN or use --token-file."
      ;;
    --token-file)
      [ "$#" -ge 2 ] || die "--token-file needs a path"
      read_token_file "$2"
      shift
      ;;
    --provider)
      [ "$#" -ge 2 ] || die "--provider needs a value"
      PROVIDER=$2
      shift
      ;;
    --model)
      [ "$#" -ge 2 ] || die "--model needs a value"
      MODEL=$2
      MODEL_SET=1
      shift
      ;;
    --base-url)
      [ "$#" -ge 2 ] || die "--base-url needs a value"
      BASE_URL=$2
      shift
      ;;
    --source)
      [ "$#" -ge 2 ] || die "--source needs a directory"
      DOTFILES_SOURCE=$2
      shift
      ;;
    --anthropic) USE_ANTHROPIC=1 ;;
    --yes|-y) DOTFILES_ASSUME_YES=1 ;;
    --tmux-only) TMUX_ONLY=1 ;;
    --dry-run) DOTFILES_DRY_RUN=1 ;;
    --offline) DOTFILES_OFFLINE=1 ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown option: $1" ;;
  esac
  shift
done

if [ "$USE_ANTHROPIC" -eq 1 ]; then
  PROVIDER="openai"
  [ -z "$BASE_URL" ] && BASE_URL="$ANTHROPIC_BASE_URL"
  [ "$MODEL_SET" -eq 0 ] && MODEL="claude-sonnet-4-5"
fi

if [ -z "$DOTFILES_SOURCE" ]; then
  if [ -f "$SCRIPT_DIR/../.tmux.conf" ]; then
    DOTFILES_SOURCE=$(abspath "$SCRIPT_DIR/..")
  else
    die "Pass --source with the dotfiles checkout."
  fi
else
  DOTFILES_SOURCE=$(abspath "$DOTFILES_SOURCE")
fi

# Double-quoted YAML scalar. Control characters are rejected so a value
# cannot break out of the line and add keys such as base_url.
yaml_quote() {
  local value=$1
  if contains_control "$value"; then
    die "A TmuxAI setting contains a newline or other control character."
  fi
  value=${value//\\/\\\\}
  value=${value//\"/\\\"}
  printf '"%s"' "$value"
}

install_tmux_conf() {
  if [ "$DOTFILES_OFFLINE" -eq 1 ]; then
    have tmux || die "tmux is not installed. Install it from an internal mirror, then re-run."
  elif [ "$DOTFILES_SKIP_PACKAGES" -eq 0 ]; then
    ensure_packages
  fi
  link_file "$(config_link_source .tmux.conf)" "$HOME/.tmux.conf"
  if [ "$DOTFILES_SKIP_PACKAGES" -eq 0 ] && have tmux && tmux info >/dev/null 2>&1; then
    if [ "$DOTFILES_DRY_RUN" -eq 0 ]; then
      tmux source-file "$HOME/.tmux.conf" >/dev/null 2>&1 || warn "Could not reload the running tmux server"
    fi
  fi
}

install_tmuxai() {
  if [ "$DOTFILES_OFFLINE" -eq 1 ]; then
    die "TmuxAI is installed from the network. Run it on an online machine."
  fi
  if [ -z "$TOKEN" ]; then
    die "No API token. Set TMUXAI_API_TOKEN or pass --token-file."
  fi
  if [ "$DOTFILES_DRY_RUN" -eq 1 ]; then
    info "would install TmuxAI and write $TMUXAI_CONFIG"
    return 0
  fi
  if have tmuxai; then
    ok "TmuxAI already installed ($(command -v tmuxai))"
  else
    info "Installing TmuxAI"
    if have brew && brew install tmuxai; then
      ok "TmuxAI installed with Homebrew"
    else
      # get.tmuxai.dev does not publish a checksum. Homebrew bottles do, so
      # that path is preferred. This fallback saves the script, then runs it.
      local installer
      installer=$(mktemp)
      if curl -fsSL "$TMUXAI_INSTALL_URL" -o "$installer" && bash "$installer"; then
        rm -f "$installer"
        ok "TmuxAI installed"
      else
        rm -f "$installer"
        die "Could not install TmuxAI."
      fi
    fi
  fi

  mkdir -p "$TMUXAI_CONFIG_DIR"
  chmod 700 "$TMUXAI_CONFIG_DIR"
  if [ -f "$TMUXAI_CONFIG" ] && [ "$DOTFILES_ASSUME_YES" -ne 1 ]; then
    if [ ! -r /dev/tty ]; then
      die "TmuxAI config exists at $TMUXAI_CONFIG. Re-run with --yes to overwrite it."
    fi
    printf 'Overwrite %s? [y/N] ' "$TMUXAI_CONFIG"
    local reply
    read -r reply </dev/tty || reply=""
    case "$reply" in
      y|Y|yes|YES) ;;
      *) die "Existing TmuxAI config left unchanged." ;;
    esac
  fi
  if [ -f "$TMUXAI_CONFIG" ]; then
    local backup
    backup=$(backup_path "$TMUXAI_CONFIG")
    cp "$TMUXAI_CONFIG" "$backup"
    ok "backed up $TMUXAI_CONFIG -> $backup"
  fi

  local umask_old quoted_name quoted_provider quoted_model quoted_token quoted_base
  for value in "$MODEL_NAME" "$PROVIDER" "$MODEL" "$TOKEN" "$BASE_URL"; do
    if contains_control "$value"; then
      die "A TmuxAI setting contains a newline or other control character."
    fi
  done
  umask_old=$(umask)
  umask 077
  quoted_name=$(yaml_quote "$MODEL_NAME")
  quoted_provider=$(yaml_quote "$PROVIDER")
  quoted_model=$(yaml_quote "$MODEL")
  quoted_token=$(yaml_quote "$TOKEN")
  quoted_base=""
  if [ -n "$BASE_URL" ]; then
    quoted_base=$(yaml_quote "$BASE_URL")
  fi
  {
    echo "# Generated by setup-tmuxai.sh on $(date +%Y-%m-%d)"
    echo "# https://github.com/alvinunreal/tmuxai/blob/main/config.example.yaml"
    echo
    echo "default_model: $quoted_name"
    echo
    echo "models:"
    echo "  $quoted_name:"
    echo "    provider: $quoted_provider"
    echo "    model: $quoted_model"
    echo "    api_key: $quoted_token"
    if [ -n "$quoted_base" ]; then
      echo "    base_url: $quoted_base"
    fi
  } > "$TMUXAI_CONFIG"
  umask "$umask_old"
  chmod 600 "$TMUXAI_CONFIG"
  ok "Wrote $TMUXAI_CONFIG (provider=$PROVIDER, model=$MODEL)"
  warn "The API token is stored in $TMUXAI_CONFIG (mode 0600)."
}

install_tmux_conf
if [ "$TMUX_ONLY" -eq 0 ]; then
  install_tmuxai
fi
