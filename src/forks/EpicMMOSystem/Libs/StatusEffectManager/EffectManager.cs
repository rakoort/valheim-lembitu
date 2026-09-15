using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using System.Runtime.CompilerServices;
using HarmonyLib;
using JetBrains.Annotations;
using UnityEngine;

namespace StatusEffectManager;

internal static class EffectManager
{
	private struct BundleId
	{
		[UsedImplicitly]
		public string assetBundleFileName;

		[UsedImplicitly]
		public string folderName;
	}

	private static readonly Dictionary<BundleId, AssetBundle> bundleCache;

	static EffectManager()
	{
		bundleCache = new Dictionary<BundleId, AssetBundle>();
		Harmony harmony = new Harmony("org.bepinex.helpers.StatusEffectManager");
		harmony.Patch(AccessTools.DeclaredMethod(typeof(ObjectDB), "Awake"), null, new HarmonyMethod(AccessTools.DeclaredMethod(typeof(EffectManager), "Patch_ObjectDBInit")));
		harmony.Patch(AccessTools.DeclaredMethod(typeof(ZNetScene), "Awake"), null, new HarmonyMethod(AccessTools.DeclaredMethod(typeof(EffectManager), "Patch_ZNetSceneAwake")));
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
			AssetBundle? obj = Resources.FindObjectsOfTypeAll<AssetBundle>().FirstOrDefault((AssetBundle a) => a.name == assetBundleFileName) ?? AssetBundle.LoadFromStream(Assembly.GetExecutingAssembly().GetManifestResourceStream(Assembly.GetExecutingAssembly().GetName().Name + ((folderName == "") ? "" : ".") + folderName + "." + assetBundleFileName));
			AssetBundle result = obj;
			dictionary[key] = obj;
			return result;
		}
		return value;
	}

	public static StatusEffect RegisterCustomSE(string assetBundleFileName, string customEffectName, string folderName = "assets")
	{
		return RegisterCustomSE(RegisterAssetBundle(assetBundleFileName, folderName), customEffectName);
	}

	public static StatusEffect RegisterCustomSE(AssetBundle assets, string customEffectName)
	{
		StatusEffect statusEffect = (StatusEffect)assets.LoadAsset<ScriptableObject>(customEffectName);
		CustomSE.CustomSEs.Add(statusEffect);
		return statusEffect;
	}

	public static StatusEffect RegisterCustomSE(StatusEffect customSE, string customEffectName)
	{
		customSE.name = customEffectName;
		CustomSE.CustomSEs.Add(customSE);
		return customSE;
	}

	[HarmonyPriority(700)]
	private static void Patch_ObjectDBInit(ObjectDB __instance)
	{
		foreach (StatusEffect customSE in CustomSE.CustomSEs)
		{
			if (!__instance.m_StatusEffects.Contains(customSE))
			{
				__instance.m_StatusEffects.Add(customSE);
			}
		}
		__instance.UpdateRegisters();
	}

	[HarmonyPriority(700)]
	private static void Patch_ZNetSceneAwake(ZNetScene __instance)
	{
		foreach (KeyValuePair<SE_Item, string> addToPrefab in CustomSE.AddToPrefabs)
		{
			try
			{
				GameObject prefab = __instance.GetPrefab(addToPrefab.Value);
				ItemDrop itemDrop = (prefab ? prefab.GetComponent<ItemDrop>() : prefab.GetComponentInChildren<ItemDrop>());
				Aoe aoe = (prefab ? prefab.GetComponent<Aoe>() : prefab.GetComponentInChildren<Aoe>());
				EffectArea effectArea = (prefab ? prefab.GetComponent<EffectArea>() : prefab.GetComponentInChildren<EffectArea>());
				if ((bool)itemDrop)
				{
					switch (addToPrefab.Key.Type)
					{
					case EffectType.Equip:
						itemDrop.m_itemData.m_shared.m_equipStatusEffect = addToPrefab.Key.Effect;
						break;
					case EffectType.Attack:
						itemDrop.m_itemData.m_shared.m_attackStatusEffect = addToPrefab.Key.Effect;
						break;
					case EffectType.Consume:
						itemDrop.m_itemData.m_shared.m_consumeStatusEffect = addToPrefab.Key.Effect;
						break;
					case EffectType.Set:
						itemDrop.m_itemData.m_shared.m_setSize = 1;
						itemDrop.m_itemData.m_shared.m_setName = addToPrefab.Key.Effect.name;
						itemDrop.m_itemData.m_shared.m_setStatusEffect = addToPrefab.Key.Effect;
						break;
					default:
						throw new ArgumentOutOfRangeException();
					}
				}
				else if ((bool)aoe)
				{
					aoe.m_statusEffect = addToPrefab.Key.Effect.name;
				}
				else if ((bool)effectArea)
				{
					effectArea.m_statusEffect = addToPrefab.Key.Effect.name;
				}
				else
				{
					Debug.LogWarning("The prefab '" + prefab.name + "' does not have an ItemDrop, AOE, or EffectArea component. Cannot add the StatusEffect to the prefab.");
				}
			}
			catch (Exception arg)
			{
				Debug.LogWarning($"BROKE : {arg}");
			}
		}
	}
}
