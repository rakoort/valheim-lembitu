#!/usr/bin/env bash
# Direct requirements, alternatives, upgrade costs and profession precedence.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PYTHONDONTWRITEBYTECODE=1 python3 - "$REPO_ROOT" <<'PY'
import importlib.util
import sys
from pathlib import Path
spec = importlib.util.spec_from_file_location("ladder", Path(sys.argv[1]) / "scripts/generate-ladder.py")
ladder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ladder)
def recipe(name, resources, kind="OneHandedWeapon", skill="Swords", only_one=False):
    return dict(prefab=name, itemType=kind, skill=skill, station="forge", food=0,
                maxQuality=2, onlyOne=only_one, resources=[dict(prefab=n, amounts=a) for n,a in resources])
iron = recipe("SwordIron", [("Wood", [2,1]), ("Iron", [20,10])])
assert ladder.recipe_rung(iron, {"Iron":20}) == 20
upgrade = recipe("Sword", [("Wood", [2,1]), ("Silver", [0,5])])
assert ladder.recipe_rung(upgrade, {"Silver":30}) == 30
assert ladder.recipe_rung(recipe("Choice", [("Wood", [2,1]), ("Iron", [2,1])], only_one=True), {"Iron":20}) == 0
assert ladder.recipe_rung(recipe("Unknown", [("Mystery", [1,1])]), {}) == 0
assert ladder.profession(recipe("Scythe", [], "TwoHandedWeapon", "Farming")) == "Farming"
assert ladder.profession(recipe("BackpackPlains", [], "Shoulder", "None")) == "midnightsfx.hauling"
assert ladder.profession(recipe("BombOoze", [], "OneHandedWeapon", "None")) is None
assert ladder.profession(recipe("BarleyWineBase", [], "Material")) == "Herbalist"
# A cooking-station gear conversion must gate its Material recipe, not just the
# finished weapon's upgrade recipe; unknown material overrides cannot lower WAP.
data = dict(maps={"materials":{"Iron":"defeated_gdking", "Gold":"defeated_fader"}},
            recipes=[recipe("SwordGoldUncooked", [("Gold", [20,0])], "Material")],
            conversions=[dict(input="SwordGoldUncooked", output="SwordGold")],
            itemTypes={"SwordGold":"OneHandedWeapon"})
rules, excluded, overrides = ladder.generate(data)
assert rules == {"SwordGoldUncooked": ("Blacksmithing",70)}
assert excluded == {} and overrides == {}
print("pass: rung mapping, alternatives, upgrades, missiles, profession precedence and foundry gear")
PY
