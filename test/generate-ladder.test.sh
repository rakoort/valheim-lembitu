#!/usr/bin/env bash
# Deep North selection, alternative costs, upgrade costs and foundry conversions.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PYTHONDONTWRITEBYTECODE=1 python3 - "$REPO_ROOT" <<'PY'
import importlib.util
import sys
from pathlib import Path
spec = importlib.util.spec_from_file_location("deep_north", Path(sys.argv[1]) / "scripts/generate-ladder.py")
generator = importlib.util.module_from_spec(spec)
spec.loader.exec_module(generator)

def recipe(name, resources, kind="OneHandedWeapon", skill="Swords", only_one=False):
    return dict(prefab=name, itemType=kind, skill=skill, station="forge", food=0,
                maxQuality=2, onlyOne=only_one,
                resources=[dict(prefab=n, amounts=a) for n, a in resources])

data = dict(maps={"materials":{"Iron":"defeated_gdking", "MappedNorth":"defeated_fader"}},
            recipes=[recipe("IronSword", [("Iron", [20,10])]),
                     recipe("NorthSword", [("Gold", [20,10])]),
                     recipe("NorthUpgrade", [("Gold", [0,5]), ("Wood", [2,1])]),
                     recipe("Choice", [("Wood", [2,1]), ("Gold", [2,1])], only_one=True),
                     recipe("NorthChoice", [("Gold", [2,1]), ("MappedNorth", [2,1])], only_one=True),
                     recipe("Unknown", [("Mystery", [1,1])]),
                     recipe("UnusedNorth", [("Gold", [0,0])]),
                     recipe("Snowball", [("Ice", [2,1])], skill="None"),
                     recipe("FishingBaitDeepNorth", [("Gold", [2,1])], "Material"),
                     recipe("BH_NorthHerb", [("Gold", [2,1])], "Material"),
                     recipe("NorthFood", [("MooseMeat", [2,1])], "Consumable"),
                     recipe("SwordGoldUncooked", [("Gold", [20,0])], "Material"),
                     recipe("FoodUncooked", [("Gold", [2,0])], "Material"),
                     recipe("MappedShield", [("MappedNorth", [2,1])], "Shield")],
            conversions=[dict(input="SwordGoldUncooked", output="SwordGold"),
                         dict(input="FoodUncooked", output="FoodCooked")],
            itemTypes={"SwordGold":"OneHandedWeapon", "FoodCooked":"Consumable"})
assert generator.generate(data) == ["MappedShield", "NorthChoice", "NorthSword", "NorthUpgrade",
                                   "SwordGold", "SwordGoldUncooked"]
# Duplicate native recipe rows must not duplicate list entries.
data["recipes"].append(data["recipes"][1])
assert generator.generate(data).count("NorthSword") == 1
# A conversion without a Deep North input recipe is not a biome inference.
data["conversions"].append(dict(input="IronSword", output="IronSwordCooked"))
data["itemTypes"]["IronSwordCooked"] = "OneHandedWeapon"
assert "IronSwordCooked" not in generator.generate(data)
print("pass: Deep North gear, upgrades, alternatives, exclusions and both sides of foundry conversion")
PY
