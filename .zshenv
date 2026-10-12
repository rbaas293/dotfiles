# Add '~/.local/bin' and its subdirectories to $PATH when that directory exists.
if [ -d "$HOME/.local/bin" ]; then
  export PATH="$PATH:$(find "$HOME/.local/bin" -type d -print | paste -sd ':' -)"
fi
