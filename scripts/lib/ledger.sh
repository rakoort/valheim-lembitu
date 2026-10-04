# Shared by scripts/install-plugins.sh and scripts/stage-stack.sh: the one policy for paths that
# can end up in the installer manifest, because prune-mirror embeds manifest entries in a shell
# script that runs inside the lloesche/valheim-server container.

safe_ledger_entry() {
  # '#' and spaces stay allowed although no pinned package ships such a name: Seasonality's texture
  # names had both, it was cut on 2026-10-04, and the manifests it left on servers can only be pruned
  # if their entries still pass this check. Entries are always double-quoted when replayed.
  [[ "$1" =~ ^[A-Za-z0-9._+()@#\ -]+(/[A-Za-z0-9._+()@#\ -]+)*$ ]] || return 1
  # Dot-leading components are refused anywhere in the path, not only at the front: paths carry a
  # tree prefix (plugins/...), so a dotfile inside a tree would slip past a leading-only check, and
  # traversal-shaped components are errors rather than something to escape.
  case "$1" in .*|*/.*|*/../*|*/..|*/.) return 1 ;; esac
  return 0
}
