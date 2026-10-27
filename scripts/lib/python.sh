# shellcheck shell=bash
# Run python3 on hosts that have no python3 on PATH. astral-bicep and astral-tricep are NixOS
# machines without a system python, so the ops scripts take it from nixpkgs, pinned to this
# repository's flake.lock, the same way the native test tooling uses `nix shell nixpkgs#python3`.
#
#   . "$REPO_ROOT/scripts/lib/python.sh"; run_python script.py args...

run_python() {
  if command -v python3 >/dev/null 2>&1; then
    python3 "$@"
  else
    nix shell --inputs-from "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)" \
      nixpkgs#python3 --command python3 "$@"
  fi
}
