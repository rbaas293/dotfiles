# dotfiles

An amazing vim config, a mediocre zsh config, and (for those with no fear) emojis in your terminal.

`setup.sh` installs zsh, tmux, and vim on macOS (Homebrew) and Debian/Ubuntu (`apt-get`). It symlinks `.zshrc`, `.zshenv`, `.tmux.conf`, and `.vimrc`. It does not install `.zprofile`, i3, or X11.

## Online install

```bash
git clone git@github.com:rbaas293/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./setup.sh --yes
```

`--source DIR` uses that checkout and skips the SSH clone. `--no-chsh` leaves the login shell alone. `--dry-run` prints the actions.

TmuxAI is optional and stays out of the offline archive:

```bash
TMUXAI_API_TOKEN=your-token ./setup.sh --with-tmuxai
./setup.sh --with-tmuxai --token-file ~/.config/tmuxai-token
```

The token is read from the environment or from a file. It is not accepted as a command argument.

## Air-gapped install

On a machine with network:

```bash
./setup.sh --yes --pack --zipapp
```

That writes:

- `build/dotfiles-offline.tar.gz` and `build/dotfiles-offline.tar.gz.sha256`
- `build/dotfiles.pyz` and `build/dotfiles.pyz.sha256`, one executable file

The archive holds the installer, the four config files, Oh My Zsh, the zsh plugins, and the Vim bundles. It does not contain `.git`, `.zprofile`, or a TmuxAI token. `zsh`, `tmux`, and `vim` must already be on the air-gapped machine (from an internal mirror). The archive does not download them.

Check the tar, then install:

```bash
sha256sum -c dotfiles-offline.tar.gz.sha256   # Linux
shasum -a 256 -c dotfiles-offline.tar.gz.sha256   # macOS
tar -xzf dotfiles-offline.tar.gz
cd dotfiles-offline
./setup.sh --offline --no-chsh
```

Or copy the zipapp and run it. The target also needs `python3`. This is a Python zipapp, not a native binary.

```bash
sha256sum -c dotfiles.pyz.sha256          # Linux
shasum -a 256 -c dotfiles.pyz.sha256      # macOS
chmod +x dotfiles.pyz
./dotfiles.pyz --no-chsh
```

`./dotfiles.pyz` extracts the payload, runs `setup.sh --offline`, and removes the extract. Symlinks point at `~/.local/share/dotfiles`, so they stay valid after that.

`--offline` does not call `curl`, `git`, `brew`, or `apt`.

## Vim

Indentation is spaces, width 4 (`expandtab`, `tabstop`, `softtabstop`, `shiftwidth`). Makefiles stay real tabs. The installer clones the Vim plugins with git and does not leave an interactive vim session open.

## Sync files back

`update_dotfiles.py --install` copies files into the home directory. `-f` matches exact relative paths, and an existing destination is moved aside first.

```bash
python3 update_dotfiles.py --install -f .zshrc
```
