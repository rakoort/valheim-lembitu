# Shared by scripts/install-plugins.sh and scripts/stage-stack.sh: the one policy for paths that
# can end up in the installer manifest, because prune-mirror embeds manifest entries in a shell
# script that runs inside the lloesche/valheim-server container. Traversal is refused on top of
# that: anything else is an error rather than something to escape.

safe_ledger_entry() {
  [[ "$1" =~ ^[A-Za-z0-9._+()@-]+(/[A-Za-z0-9._+()@-]+)*$ ]] || return 1
  # Any dot-leading component, not just a leading dot: paths carry a tree prefix (plugins/...),
  # so a dotfile inside a tree would otherwise slip past a leading-only check. Traversal is
  # refused on top of that: anything else is an error rather than something to escape.
  case "$1" in .*|*/.*|*/../*|*/..|*/.) return 1 ;; esac
  return 0
}
