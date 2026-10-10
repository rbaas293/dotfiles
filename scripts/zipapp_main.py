#!/usr/bin/env python3
"""Extract this zipapp and install from the bundled offline cache.

The target needs python3, zsh, tmux, and vim. Nothing is downloaded.
Configs are copied to ~/.local/share/dotfiles before the temp extract is
removed, so the symlinks stay valid.
"""

import os
import shutil
import stat
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path


def archive_path():
    candidate = Path(sys.argv[0]).resolve()
    if candidate.is_file() and zipfile.is_zipfile(candidate):
        return candidate
    raise SystemExit("dotfiles.pyz: could not open the zipapp archive")


def forward_args(argv):
    cleaned = []
    index = 0
    while index < len(argv):
        arg = argv[index]
        if arg == "--offline":
            index += 1
            continue
        if arg == "--source":
            index += 2
            continue
        cleaned.append(arg)
        index += 1
    return cleaned


def main():
    archive = archive_path()
    dest = Path(tempfile.mkdtemp(prefix="dotfiles-"))
    try:
        with zipfile.ZipFile(archive) as bundle:
            bundle.extractall(dest)
        setup = dest / "setup.sh"
        if not setup.is_file():
            raise SystemExit("dotfiles.pyz: archive has no setup.sh")
        setup.chmod(setup.stat().st_mode | stat.S_IEXEC)
        scripts = dest / "scripts"
        if scripts.is_dir():
            for path in scripts.glob("*.sh"):
                path.chmod(path.stat().st_mode | stat.S_IEXEC)
        env = os.environ.copy()
        env["DOTFILES_PERSIST"] = str(Path.home() / ".local" / "share" / "dotfiles")
        command = [
            "bash",
            str(setup),
            "--offline",
            "--source",
            str(dest),
            *forward_args(sys.argv[1:]),
        ]
        raise SystemExit(subprocess.call(command, env=env))
    finally:
        shutil.rmtree(dest, ignore_errors=True)


if __name__ == "__main__":
    main()
