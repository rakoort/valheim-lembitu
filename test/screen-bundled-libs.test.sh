#!/usr/bin/env bash
# Behaviour tests for scripts/screen-bundled-libs.sh: the ADR-0002 screen for a package's bundled
# managed libraries.
#
# The screen reads real IL, so these tests build real assemblies with the .NET SDK rather than
# fixtures of text. Two cases matter and both are behavioural:
#
#   * a library compiled against a field that the referenced assembly later turned into a `const`
#     must be reported - that is the exact failure ADR-0002 describes, and the screen exists to
#     catch it before the first broadcast rather than at runtime;
#   * a library with no such reference must come back clean, so the check cannot pass by always
#     failing.
#
# A missing prerequisite (no SDK, no ilspycmd) skips with a notice rather than passing, because a
# skipped screen must never read as a clean package.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCREEN="$REPO_ROOT/scripts/screen-bundled-libs.sh"

pass=0 fail=0
report() {
  printf '%s: %s\n' "$([ "$1" = ok ] && echo pass || echo FAIL)" "$2"
  [ "$1" = ok ] && pass=$((pass + 1)) || fail=$((fail + 1))
}

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

if ! command -v dotnet >/dev/null 2>&1; then
  echo "skip: the screen tests build assemblies and need dotnet"
  printf '\n%d passed, %d failed\n' "$pass" "$fail"
  exit 0
fi

# The screen needs ilspycmd. It supplies its own through nix when absent, so only skip when neither
# is present - and say so loudly rather than reporting a pass.
if ! command -v ilspycmd >/dev/null 2>&1 && ! command -v nix >/dev/null 2>&1; then
  echo "skip: the screen needs ilspycmd or nix to supply it"
  printf '\n%d passed, %d failed\n' "$pass" "$fail"
  exit 0
fi

# --- the fake game and two consumers ------------------------------------------------------------

mkdir -p "$WORK/game" "$WORK/field" "$WORK/const"
cat > "$WORK/game/game.csproj" <<'EOF'
<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup>
<TargetFramework>net8.0</TargetFramework><AssemblyName>FakeValheim</AssemblyName><Deterministic>true</Deterministic>
</PropertyGroup></Project>
EOF
cat > "$WORK/game/Lib.cs" <<'EOF'
namespace FakeValheim { public class ZRoutedRpc { public static long Everybody = 0L; } }
EOF

# The consumer compiled while Everybody is still a field: this is the stale build.
cat > "$WORK/field/field.csproj" <<'EOF'
<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup>
<TargetFramework>net8.0</TargetFramework><AssemblyName>StaleLib</AssemblyName>
</PropertyGroup>
<ItemGroup><Reference Include="FakeValheim"><HintPath>../game/bin/Debug/net8.0/FakeValheim.dll</HintPath></Reference></ItemGroup></Project>
EOF
cat > "$WORK/field/Stale.cs" <<'EOF'
namespace StaleLib { public class Sender { public static long Target() => FakeValheim.ZRoutedRpc.Everybody; } }
EOF

# A consumer that never touches the member: the clean case.
cat > "$WORK/const/const.csproj" <<'EOF'
<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup>
<TargetFramework>net8.0</TargetFramework><AssemblyName>CleanLib</AssemblyName>
</PropertyGroup>
<ItemGroup><Reference Include="FakeValheim"><HintPath>../game/bin/Debug/net8.0/FakeValheim.dll</HintPath></Reference></ItemGroup></Project>
EOF
cat > "$WORK/const/Clean.cs" <<'EOF'
namespace CleanLib { public class Unrelated { public static int Value() => 1 + 1; } }
EOF

( cd "$WORK/game"  && dotnet build -v q --nologo >/dev/null 2>&1 )
( cd "$WORK/field" && dotnet build -v q --nologo >/dev/null 2>&1 )
( cd "$WORK/const" && dotnet build -v q --nologo >/dev/null 2>&1 )
STALE="$WORK/field/bin/Debug/net8.0/StaleLib.dll"
CLEAN="$WORK/const/bin/Debug/net8.0/CleanLib.dll"

# --- now turn the game member into a const ------------------------------------------------------

cat > "$WORK/game/Lib.cs" <<'EOF'
namespace FakeValheim { public class ZRoutedRpc { public const long Everybody = 0L; } }
EOF
( cd "$WORK/game" && dotnet build -v q --nologo >/dev/null 2>&1 )

# --- 1. the stale build is reported -------------------------------------------------------------

if out="$(VALHEIM_MANAGED="$WORK/game/bin/Debug/net8.0" SCREEN_GAME_ASSEMBLY=FakeValheim bash "$SCREEN" "$STALE" 2>&1)"; then
  rc=0
else
  rc=$?
fi
if [[ $rc == 1 ]] && grep -q "ZRoutedRpc::Everybody" <<<"$out" && grep -q "Target" <<<"$out"; then
  report ok "a library reading a field the game turned into a const is reported with its method"
else
  echo "  rc=$rc"; echo "$out" | sed 's/^/  /'
  report fail "a library reading a field the game turned into a const is reported with its method"
fi

# --- 2. a library with no such reference is clean ------------------------------------------------

if out="$(VALHEIM_MANAGED="$WORK/game/bin/Debug/net8.0" SCREEN_GAME_ASSEMBLY=FakeValheim bash "$SCREEN" "$CLEAN" 2>&1)"; then
  rc=0
else
  rc=$?
fi
if [[ $rc == 0 ]] && grep -q "^clean:" <<<"$out"; then
  report ok "a library with no stale game-member reference comes back clean"
else
  echo "  rc=$rc"; echo "$out" | sed 's/^/  /'
  report fail "a library with no stale game-member reference comes back clean"
fi

# --- 3. missing game references refuse rather than pass ------------------------------------------

if out="$(VALHEIM_MANAGED="$WORK/nonexistent" bash "$SCREEN" "$CLEAN" 2>&1)"; then
  rc=0
else
  rc=$?
fi
if [[ $rc == 2 ]] && grep -qi "extract-refs" <<<"$out"; then
  report ok "an absent game reference is a refusal, never a pass"
else
  echo "  rc=$rc"; echo "$out" | sed 's/^/  /'
  report fail "an absent game reference is a refusal, never a pass"
fi

# --- 4. --dir screens a whole staged package -----------------------------------------------------

mkdir -p "$WORK/pkg"
cp "$STALE" "$WORK/pkg/"
if out="$(VALHEIM_MANAGED="$WORK/game/bin/Debug/net8.0" SCREEN_GAME_ASSEMBLY=FakeValheim bash "$SCREEN" --dir "$WORK/pkg" 2>&1)"; then
  rc=0
else
  rc=$?
fi
if [[ $rc == 1 ]] && grep -q "ZRoutedRpc::Everybody" <<<"$out"; then
  report ok "--dir screens every DLL in a staged package"
else
  echo "  rc=$rc"; echo "$out" | sed 's/^/  /'
  report fail "--dir screens every DLL in a staged package"
fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[[ $fail -eq 0 ]]
