#!/usr/bin/env python3
"""Generate ADR-0023 ItemRequirement rules from a native ObjectDB JSON dump.

Input: maps (WAP's BossItemKeysList, MaterialKeysList, FoodKeysList), recipes
(prefab, itemType, station, food, onlyOne, maxQuality, resources[{prefab,amounts}]),
and the native spawns/vegetation/drops evidence. Capture after mod registration
and enforced configuration; keep the raw dump with the boot evidence, not in git.
The dump's amounts are Recipe.Requirement.GetAmount(quality), not guessed costs.
Use --report PATH to retain every excluded item and override-dependent rule.
"""
import argparse
import collections
import hashlib
import json
from pathlib import Path

KEYS = {key: n * 10 for n, key in enumerate(("", "defeated_eikthyr",
    "defeated_gdking", "defeated_bonemass", "defeated_dragon",
    "defeated_goblinking", "defeated_queen", "defeated_fader"))}
GEAR = {"OneHandedWeapon", "TwoHandedWeapon", "TwoHandedWeaponLeft", "Bow",
        "Shield", "Helmet", "Chest", "Legs", "Shoulder"}
# Explicit material overrides, never item-name biome inference. WAP remains the
# floor. Each row cites the native source path or the pinned Herbalist code.
HERB_SOURCE = "Herbalist 1.5.0 Herbalist.Functions/VegetationSetup.cs"
OVERRIDES = {
    "BH_Boswellia": (10, HERB_SOURCE + ":51-61"),
    "BH_Bjorncap": (10, HERB_SOURCE + ":62-72"),
    "BH_SkaldsIvy": (10, HERB_SOURCE + ":73-83"),
    "BH_Chicory": (20, HERB_SOURCE + ":84-94"),
    "BH_LokisTrickcap": (20, HERB_SOURCE + ":95-105"),
    "BH_AslaugsHerb": (20, HERB_SOURCE + ":106-116"),
    "BH_Daisy": (30, HERB_SOURCE + ":117-127"),
    "BH_SeidrBlossoms": (30, HERB_SOURCE + ":128-138"),
    "BH_HelshadeFungus": (30, HERB_SOURCE + ":139-149"),
    "BH_Echinacea": (40, HERB_SOURCE + ":150-160"),
    "BH_ThorsToadstool": (40, HERB_SOURCE + ":161-171"),
    "BH_Lavender": (40, HERB_SOURCE + ":172-182"),
    "BH_Valhallaberry": (50, HERB_SOURCE + ":183-193"),
    "BH_NordicFirebloom": (50, HERB_SOURCE + ":194-204"),
    "TrophyFrostTroll": (10, "dump spawns[Troll].biome=BlackForest; drops[Troll]"),
    "TrophyAbomination": (20, "dump spawns[Abomination].biome=Swamp; drops[Abomination]"),
    "TrophyFenring": (30, "dump spawns[Fenring].biome=Mountain; drops[Fenring]"),
    "TrophyHatchling": (30, "dump spawns[Hatchling].biome=Mountain; drops[Hatchling]"),
    "TrophyGoblin": (40, "dump spawns[Goblin].biome=Plains; drops[Goblin] (native home spawn, not raid alternatives)"),
    "TrophyLox": (40, "dump spawns[Lox].biome=Plains; drops[Lox]"),
    "TrophyCharredMelee": (60, "dump spawns[Charred_Melee].biome=AshLands; drops[Charred_Melee] (home spawn)"),
    "TrophySerpent": (20, "dump spawns[Serpent].biome=Ocean; drops[Serpent]; WAP FoodKeysList SerpentMeat=defeated_gdking"),
    "MooseHide": (70, "dump spawns[Moose].biome=DeepNorth; drops[Moose]"),
    "MooseSinew": (70, "dump spawns[Moose].biome=DeepNorth; drops[Moose]"),
    "MooseMeat": (70, "dump spawns[Moose].biome=DeepNorth; drops[Moose]"),
    "TrophyMoose": (70, "dump spawns[Moose].biome=DeepNorth; drops[Moose]"),
    "SealHide": (70, "dump spawns[Seal].biome=DeepNorth; drops[Seal]"),
    "SealBlubber": (70, "dump spawns[Seal].biome=DeepNorth; drops[Seal]"),
    "NornThread": (70, "dump spawns[JotunWitch].biome=DeepNorth; drops[JotunWitch]"),
    "ElakingHairBundle": (70, "dump spawns[Elaking].biome=DeepNorth; drops[Elaking]"),
    "BarkaBranch": (70, "dump spawns[Barka].biome=DeepNorth; drops[Barka]"),
    "Gold": (70, "dump locations[DN_gammeltrollFrac01].biome=DeepNorth contains TrollFrost_Frac_legs; materialSources[TrollFrost_Frac_legs].MineRock5.m_dropItems=GoldOre; DataForge/pieces.reference.yml:374 GoldOre -> Gold"),
    "Frostwood": (70, "dump vegetation[FirTree_oldLog_deepnorth].biome=DeepNorth; materialSources[FirTree_oldLog_deepnorth].DropOnDestroyed=Frostwood"),
    "Ice": (70, "dump vegetation[ice1].biome=DeepNorth; materialSources[ice1].DropOnDestroyed=Ice"),
    "Kale": (70, "dump vegetation[Pickable_SeedKale].biome=DeepNorth; pickables[Pickable_SeedKale].item=KaleSeeds; plants[sapling_Kale].grown=Pickable_Kale; pickables[Pickable_Kale].item=Kale"),
    "Lingonberry": (70, "dump vegetation[LingonberryBush].biome=DeepNorth; pickables[LingonberryBush].item=Lingonberry"),
    "SpiceDeepNorth": (70, "dump traders[BogWitch].items[SpiceDeepNorth].key=defeated_frozenking_p3 (Deep North boss)"),
}

# Named item floors (owner, 2026-10-05; ADR-0023): three Meadows-material items climb
# early by decision, crafting only, so each speciality has one Plains-rung taste before
# its biome. A floor sets the profession too, which rescues items the classifier
# excludes (CaulkedWood is an intermediate material) or whose materials map no rung
# (BH_RunnerElixer, SA_Sadle). A mismatch with the classifier raises.
ITEM_FLOORS = {
    "BH_RunnerElixer": ("Herbalist", 40, "owner 2026-10-05 (#87): the Runner (Swift) elixir is the Herbalist taste of the Plains rung"),
    "SA_Sadle": ("midnightsfx.animalwhisper", 40, "owner 2026-10-05 (#87): SeaAnimals' saddle is the Animal Handling taste of the Plains rung"),
    "CaulkedWood": ("midnightsfx.voyager", 40, "owner 2026-10-05 (#87): OdinShip's caulked wood is the Sailing (voyager) taste of the Plains rung"),
}

def profession(recipe):
    name = recipe["prefab"]
    if recipe["itemType"] == "OneHandedWeapon" and recipe["skill"] == "None":
        return None  # Consumable missiles (bombs and Snowball), not smith gear.
    if name == "Scythe":
        return "Farming"
    if name.startswith("Backpack"):
        return "midnightsfx.hauling"
    if name.startswith("Saddle") or name == "SA_Sadle":
        return "midnightsfx.animalwhisper"
    if name.startswith("FishingBait") and name != "FishingBait":
        return "Fishing"
    if name.startswith("MeadBase") or name == "BarleyWineBase" or (name.startswith("BH_") and
            (name.endswith("Tonic") or name.endswith("Elixer"))):
        return "Herbalist"
    if recipe["itemType"] in GEAR:
        return "Blacksmithing"
    if recipe["food"] > 0 or recipe["station"] == "piece_cauldron" or (recipe["station"] == "piece_preptable" and
                             name.startswith("Feast") and name.endswith("_Material")):
        return "Cooking"
    return None


def material_rungs(data, overrides):
    # WAP 1.0.0 KeyManager.cs:846-986,1422-1432: direct lookups only;
    # unknown materials are open. Never recurse into ingredient recipes.
    result = {}
    for mapping in data["maps"].values():
        for material, key in mapping.items():
            result[material] = max(result.get(material, 0), KEYS[key])
    if overrides:
        for material, (level, _) in OVERRIDES.items():
            result[material] = max(result.get(material, 0), level)
    return result


def recipe_rung(recipe, rungs):
    # WAP KeyManager.cs:1449-1495: at least one accessible alternative for
    # requireOnlyOneIngredient; otherwise every positive requirement. Include
    # every upgrade quality, because one ItemRequirement entry gates all of them.
    per_quality = []
    for quality in range(recipe["maxQuality"]):
        levels = [rungs.get(q["prefab"], 0) for q in recipe["resources"]
                  if q["amounts"][quality] > 0]
        per_quality.append((min if recipe["onlyOne"] else max)(levels, default=0))
    return max(per_quality, default=0)


def generate(data):
    base = material_rungs(data, False)
    raised = material_rungs(data, True)
    rules, excluded, overrides = {}, {}, {}
    # Native deep-north gear is first crafted as Material, then smelted. Gate
    # that recipe too; the result item type, not an Uncooked name, proves scope.
    gear_inputs = {c["input"] for c in data["conversions"]
                   if data["itemTypes"].get(c["output"]) in GEAR}
    for recipe in data["recipes"]:
        name = recipe["prefab"]
        skill = profession(recipe)
        if name in gear_inputs:
            skill = "Blacksmithing"
        floor = ITEM_FLOORS.get(name)
        if floor is not None:
            if skill is not None and skill != floor[0]:
                raise ValueError("item floor profession mismatch for " + name + ": "
                                 + skill + " vs " + floor[0])
            skill = floor[0]
        if skill is None:
            excluded[name] = "outside profession goods (" + recipe["itemType"] + ")"
            continue
        rung = recipe_rung(recipe, raised)
        if floor is not None:
            rung = max(rung, floor[1])
        if rung == 0:
            excluded[name] = "no positive biome-mapped material: " + ", ".join(q["prefab"] for q in recipe["resources"])
            continue
        if name in rules and rules[name][0] != skill:
            raise ValueError("conflicting professions for " + name)
        rules[name] = (skill, max(rung, rules.get(name, (skill, 0))[1]))
        if rung > recipe_rung(recipe, base):
            overrides[name] = {q["prefab"]: OVERRIDES[q["prefab"]][1]
                for q in recipe["resources"] if q["prefab"] in OVERRIDES and any(n > 0 for n in q["amounts"])}
        if floor is not None:
            overrides.setdefault(name, {})["item_floor"] = floor[2]
    for name in rules:
        excluded.pop(name, None)
    return rules, excluded, overrides


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("dump", type=Path)
    parser.add_argument("--output", type=Path, default=Path("config/enforced/ItemRequirement/radamanto.ItemRequirement.professions.yml"))
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    raw = args.dump.read_bytes()
    rules, excluded, overrides = generate(json.loads(raw))
    lines = ["# Generated by scripts/generate-ladder.py; do not edit.",
             "# Native dump SHA-256: " + hashlib.sha256(raw).hexdigest()]
    for name, (skill, rung) in sorted(rules.items()):
        lines.extend(("- PrefabName: " + name,
            f"  Requirements: [{{Skill: {skill}, Level: {rung}, BlockCraft: true, BlockEquip: false, EpicMMO: false}}]"))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text("\n".join(lines) + "\n")
    report = {"counts": dict(sorted(collections.Counter(skill for skill, _ in rules.values()).items())),
              "total": len(rules), "excluded": excluded, "override_rules": overrides}
    if args.report:
        args.report.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
    print(json.dumps({"total": len(rules), "counts": report["counts"], "override_rules": sorted(overrides)}, indent=2))

if __name__ == "__main__":
    main()
