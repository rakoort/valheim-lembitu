using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using System.Runtime.CompilerServices;
using HarmonyLib;
using JetBrains.Annotations;
using UnityEngine;

namespace ItemManager;

[PublicAPI]
internal static class PrefabManager
{
	private struct BundleId
	{
		[UsedImplicitly]
		public string assetBundleFileName;

		[UsedImplicitly]
		public string folderName;
	}

	private static readonly Dictionary<BundleId, AssetBundle> bundleCache;

	private static readonly List<GameObject> prefabs;

	private static readonly List<GameObject> ZnetOnlyPrefabs;

	internal static readonly Dictionary<GameObject, Tuple<Trader, global::Trader.TradeItem>> CustomTradeItems;

	static PrefabManager()
	{
		bundleCache = new Dictionary<BundleId, AssetBundle>();
		prefabs = new List<GameObject>();
		ZnetOnlyPrefabs = new List<GameObject>();
		CustomTradeItems = new Dictionary<GameObject, Tuple<Trader, global::Trader.TradeItem>>();
		Harmony harmony = new Harmony("org.bepinex.helpers.ItemManager");
		harmony.Patch(AccessTools.DeclaredMethod(typeof(ObjectDB), "CopyOtherDB"), null, new HarmonyMethod(AccessTools.DeclaredMethod(typeof(PrefabManager), "Patch_ObjectDBInit")));
		harmony.Patch(AccessTools.DeclaredMethod(typeof(ObjectDB), "Awake"), new HarmonyMethod(AccessTools.DeclaredMethod(typeof(PrefabManager), "Patch_ObjectDBInit")));
		harmony.Patch(AccessTools.DeclaredMethod(typeof(ObjectDB), "CopyOtherDB"), new HarmonyMethod(AccessTools.DeclaredMethod(typeof(Item), "Patch_ObjectDBInit")));
		harmony.Patch(AccessTools.DeclaredMethod(typeof(ObjectDB), "Awake"), new HarmonyMethod(AccessTools.DeclaredMethod(typeof(Item), "Patch_ObjectDBInit")));
		harmony.Patch(AccessTools.DeclaredMethod(typeof(FejdStartup), "Awake"), new HarmonyMethod(AccessTools.DeclaredMethod(typeof(Item), "Patch_FejdStartup")));
		harmony.Patch(AccessTools.DeclaredMethod(typeof(ZNetScene), "Awake"), null, new HarmonyMethod(AccessTools.DeclaredMethod(typeof(Item), "Patch_ZNetSceneAwake")));
		harmony.Patch(AccessTools.DeclaredMethod(typeof(ZNetScene), "Awake"), new HarmonyMethod(AccessTools.DeclaredMethod(typeof(PrefabManager), "Patch_ZNetSceneAwake")));
		harmony.Patch(AccessTools.DeclaredMethod(typeof(InventoryGui), "UpdateRecipe"), null, null, new HarmonyMethod(AccessTools.DeclaredMethod(typeof(Item), "Transpile_InventoryGui")));
		harmony.Patch(AccessTools.DeclaredMethod(typeof(InventoryGui), "SetupRequirementList"), null, null, new HarmonyMethod(AccessTools.DeclaredMethod(typeof(Item), "Transpile_SetupRequirementList")));
		harmony.Patch(AccessTools.DeclaredMethod(typeof(Piece.Requirement), "GetAmount"), new HarmonyMethod(AccessTools.DeclaredMethod(typeof(Item), "Patch_RequirementGetAmount")));
		harmony.Patch(AccessTools.DeclaredMethod(typeof(Player), "GetAvailableRecipes"), new HarmonyMethod(AccessTools.DeclaredMethod(typeof(Item), "Patch_GetAvailableRecipesPrefix")), null, null, new HarmonyMethod(AccessTools.DeclaredMethod(typeof(Item), "Patch_GetAvailableRecipesFinalizer")), null);
		harmony.Patch(AccessTools.DeclaredMethod(typeof(Recipe), "GetRequiredStationLevel"), null, new HarmonyMethod(AccessTools.DeclaredMethod(typeof(Item), "Patch_MaximumRequiredStationLevel")));
		harmony.Patch(AccessTools.DeclaredMethod(typeof(Smelter), "OnAddFuel"), null, new HarmonyMethod(AccessTools.DeclaredMethod(typeof(Item), "Patch_OnAddSmelterInput")));
		harmony.Patch(AccessTools.DeclaredMethod(typeof(Smelter), "OnAddOre"), null, new HarmonyMethod(AccessTools.DeclaredMethod(typeof(Item), "Patch_OnAddSmelterInput")));
		harmony.Patch(AccessTools.DeclaredMethod(typeof(global::Trader), "GetAvailableItems"), null, new HarmonyMethod(AccessTools.DeclaredMethod(typeof(Item), "Patch_TraderGetAvailableItems")));
		harmony.Patch(AccessTools.DeclaredMethod(typeof(Localization), "SetupLanguage"), null, new HarmonyMethod(AccessTools.DeclaredMethod(typeof(LocalizationCache), "LocalizationPostfix")));
		harmony.Patch(AccessTools.DeclaredMethod(typeof(Localization), "LoadCSV"), null, new HarmonyMethod(AccessTools.DeclaredMethod(typeof(LocalizeKey), "AddLocalizedKeys")));
	}

	public static AssetBundle RegisterAssetBundle(string assetBundleFileName, string folderName = "assets")
	{
		BundleId key = new BundleId
		{
			assetBundleFileName = assetBundleFileName,
			folderName = folderName
		};
		if (!bundleCache.TryGetValue(key, out var value))
		{
			Dictionary<BundleId, AssetBundle> dictionary = bundleCache;
			AssetBundle? obj = Resources.FindObjectsOfTypeAll<AssetBundle>().FirstOrDefault((AssetBundle a) => a.name == assetBundleFileName) ?? AssetBundle.LoadFromStream(Assembly.GetExecutingAssembly().GetManifestResourceStream(Assembly.GetExecutingAssembly().GetName().Name + "." + folderName + "." + assetBundleFileName));
			AssetBundle result = obj;
			dictionary[key] = obj;
			return result;
		}
		return value;
	}

	public static GameObject RegisterPrefab(string assetBundleFileName, string prefabName, string folderName = "assets")
	{
		return RegisterPrefab(RegisterAssetBundle(assetBundleFileName, folderName), prefabName);
	}

	public static GameObject RegisterPrefab(AssetBundle assets, string prefabName, bool addToObjectDb = false)
	{
		return RegisterPrefab(assets.LoadAsset<GameObject>(prefabName), addToObjectDb);
	}

	public static GameObject RegisterPrefab(GameObject prefab, bool addToObjectDb = false)
	{
		if (addToObjectDb)
		{
			prefabs.Add(prefab);
		}
		else
		{
			ZnetOnlyPrefabs.Add(prefab);
		}
		return prefab;
	}

	public static void AddItemToTrader(GameObject prefab, Trader trader, uint price, uint stack = 1u, string requiredGlobalKey = null)
	{
		CustomTradeItems[prefab] = new Tuple<Trader, global::Trader.TradeItem>(trader, new global::Trader.TradeItem
		{
			m_prefab = prefab.GetComponent<ItemDrop>(),
			m_price = (int)price,
			m_stack = (int)stack,
			m_requiredGlobalKey = (requiredGlobalKey ?? "")
		});
	}

	public static void RemoveItemFromTrader(GameObject prefab)
	{
		CustomTradeItems.Remove(prefab);
	}

	[HarmonyPriority(700)]
	private static void Patch_ObjectDBInit(ObjectDB __instance)
	{
		foreach (GameObject prefab in prefabs)
		{
			if (!__instance.m_items.Contains(prefab))
			{
				__instance.m_items.Add(prefab);
			}
			ItemDrop.ItemData.SharedData shared = prefab.GetComponent<ItemDrop>().m_itemData.m_shared;
			RegisterStatusEffect(shared.m_attackStatusEffect);
			RegisterStatusEffect(shared.m_consumeStatusEffect);
			RegisterStatusEffect(shared.m_equipStatusEffect);
			RegisterStatusEffect(shared.m_setStatusEffect);
		}
		__instance.UpdateRegisters();
		void RegisterStatusEffect(StatusEffect statusEffect)
		{
			if ((object)statusEffect != null && !__instance.GetStatusEffect(statusEffect.name.GetStableHashCode()))
			{
				__instance.m_StatusEffects.Add(statusEffect);
			}
		}
	}

	[HarmonyPriority(700)]
	private static void Patch_ZNetSceneAwake(ZNetScene __instance)
	{
		foreach (GameObject item in prefabs.Concat(ZnetOnlyPrefabs))
		{
			if (!__instance.m_prefabs.Contains(item))
			{
				__instance.m_prefabs.Add(item);
			}
			else
			{
				Debug.LogWarning("ZNetScene already contains " + item.name + " it cannot be added twice.");
			}
		}
	}
}
