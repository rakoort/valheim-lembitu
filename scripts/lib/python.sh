# shellcheck shell=bash
# Run python3 on hosts that have no python3 on PATH. astral-bicep and astral-tricep are NixOS
# machines without a system python, so the ops scripts take it from nixpkgs, pinned to this
# repository's flake.lock, the same way the native test tooling uses `nix shell nixpkgs#python3`.
#
#   . "$REPO_ROOT/scripts/lib/python.sh"; run_python script.py args...
#
# REMOTE_PYTHON is the equivalent for a command sent over ssh to a host without the repository:
# it runs `python3 - ARGS`, reading the program from standard input.

run_python() {
  if command -v python3 >/dev/null 2>&1; then
    python3 "$@"
  else
    nix shell --inputs-from "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)" \
      nixpkgs#python3 --command python3 "$@"
  fi
}

# shellcheck disable=SC2016,SC2089,SC2090  # a literal script for the remote shell, not word-split here
REMOTE_PYTHON='if command -v python3 >/dev/null 2>&1; then exec python3 - "$@"; else exec nix shell nixpkgs#python3 --command python3 - "$@"; fi'
# shellcheck disable=SC2090
export REMOTE_PYTHON
