#!/usr/bin/env bash
# Keep lembitu.astral.ee pointing at astral-bicep's current home address (scripts/update-dns.py).
# Usage: scripts/update-dns.sh [--dry-run]. Runs from config/dns/lembitu-dns.timer every five minutes.
set -euo pipefail
# shellcheck source=lib/python.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib/python.sh"
run_python "$(dirname "${BASH_SOURCE[0]}")/update-dns.py" "$@"
