using System.Runtime.CompilerServices;
using BepInEx.Configuration;
using JetBrains.Annotations;

namespace ItemManager;

[PublicAPI]
internal class ItemRecipe
{
	public readonly RequiredResourceList RequiredItems = new RequiredResourceList();

	public readonly RequiredResourceList RequiredUpgradeItems = new RequiredResourceList();

	public readonly CraftingStationList Crafting = new CraftingStationList();

	public int CraftAmount = 1;

	public bool RequireOnlyOneIngredient;

	public float QualityResultAmountMultiplier = 1f;

	public ConfigEntryBase RecipeIsActive;
}
