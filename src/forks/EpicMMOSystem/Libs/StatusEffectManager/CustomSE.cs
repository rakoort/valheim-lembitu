using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Runtime.CompilerServices;
using BepInEx;
using BepInEx.Bootstrap;
using BepInEx.Configuration;
using JetBrains.Annotations;
using UnityEngine;

namespace StatusEffectManager;

[PublicAPI]
internal class CustomSE
{
	private static readonly List<CustomSE> RegisteredEffects = new List<CustomSE>();

	private static readonly Dictionary<StatusEffect, CustomSE> CustomEffectMap = new Dictionary<StatusEffect, CustomSE>();

	internal static readonly List<StatusEffect> CustomSEs = new List<StatusEffect>();

	internal static readonly Dictionary<SE_Item, string> AddToPrefabs = new Dictionary<SE_Item, string>();

	[Description("Instance of the StatusEffect.")]
	public readonly StatusEffect Effect;

	public EffectType Type;

	private string _folderName = "icons";

	private AssetBundle _assetBundle = null;

	[Description("Sets the icon for the StatusEffect. Must be 64x64")]
	public Sprite IconSprite = null;

	private string IconName = null;

	private LocalizeKey _name;

	private static Localization _english;

	private static BaseUnityPlugin _plugin;

	private static bool hasConfigSync = true;

	private static object _configSync;

	[Description("Sets the icon for the StatusEffect. Must be 64x64")]
	public string Icon
	{
		get
		{
			return IconName;
		}
		set
		{
			IconName = value;
			IconSprite = ((IconName == null) ? null : loadSprite(IconName));
			Effect.m_icon = IconSprite;
		}
	}

	[Description("Sets the in-game name for the StatusEffect")]
	public LocalizeKey Name
	{
		get
		{
			LocalizeKey name = _name;
			if (name != null)
			{
				return name;
			}
			StatusEffect effect = Effect;
			if (effect.m_name.StartsWith("$"))
			{
				_name = new LocalizeKey(effect.m_name);
			}
			else
			{
				string text = "$statuseffect_" + Effect.name.Replace(" ", "_");
				_name = new LocalizeKey(text).English(effect.m_name);
				effect.m_name = text;
			}
			return _name;
		}
	}

	private static Localization english
	{
		get
		{
			if (_english == null)
			{
				_english = new Localization();
				_english.SetupLanguage("English");
			}
			return _english;
		}
	}

	private static BaseUnityPlugin plugin
	{
		get
		{
			if ((object)_plugin == null)
			{
				IEnumerable<TypeInfo> source;
				try
				{
					source = Assembly.GetExecutingAssembly().DefinedTypes.ToList();
				}
				catch (ReflectionTypeLoadException ex)
				{
					source = from t in ex.Types
						where t != null
						select t.GetTypeInfo();
				}
				_plugin = (BaseUnityPlugin)Chainloader.ManagerObject.GetComponent(source.First((TypeInfo t) => t.IsClass && typeof(BaseUnityPlugin).IsAssignableFrom(t)));
			}
			return _plugin;
		}
	}

	private static object configSync
	{
		get
		{
			if (_configSync == null && hasConfigSync)
			{
				Type type = Assembly.GetExecutingAssembly().GetType("ServerSync.ConfigSync");
				if ((object)type != null)
				{
					_configSync = Activator.CreateInstance(type, plugin.Info.Metadata.GUID + " ItemManager");
					type.GetField("CurrentVersion").SetValue(_configSync, plugin.Info.Metadata.Version.ToString());
					type.GetProperty("IsLocked").SetValue(_configSync, true);
				}
				else
				{
					hasConfigSync = false;
				}
			}
			return _configSync;
		}
	}

	public CustomSE(string assetBundleFileName, string customEffectName, string folderName = "assets")
		: this(EffectManager.RegisterAssetBundle(assetBundleFileName, folderName), customEffectName)
	{
	}

	public CustomSE(AssetBundle bundle, string customEffectName)
	{
		Effect = EffectManager.RegisterCustomSE(bundle, customEffectName);
		RegisteredEffects.Add(this);
		CustomEffectMap[Effect] = this;
	}

	public CustomSE(string customEffectName)
	{
		Effect = ScriptableObject.CreateInstance<StatusEffect>();
		EffectManager.RegisterCustomSE(Effect, customEffectName);
		RegisteredEffects.Add(this);
		CustomEffectMap[Effect] = this;
	}

	private byte[] ReadEmbeddedFileBytes(string name)
	{
		using MemoryStream memoryStream = new MemoryStream();
		Stream manifestResourceStream = Assembly.GetExecutingAssembly().GetManifestResourceStream(Assembly.GetExecutingAssembly().GetName().Name + ((_folderName == "") ? "" : ".") + _folderName + "." + name);
		if (manifestResourceStream == null)
		{
			return null;
		}
		manifestResourceStream.CopyTo(memoryStream);
		return memoryStream.ToArray();
	}

	// Ours: upstream also accepted an icon as an embedded PNG, decoded with Texture2D.LoadImage.
	// That lives in UnityEngine.ImageConversionModule, which targets netstandard 2.1 and so cannot
	// be referenced from a net472 assembly, and this fork embeds no PNG for it to find — every
	// icon comes out of an asset bundle. See UPSTREAM.md.
	private Sprite loadSprite(string name)
	{
		Sprite sprite = _assetBundle?.LoadAsset<Sprite>(name);
		if ((object)sprite != null)
		{
			return sprite;
		}
		throw new FileNotFoundException("Could not find a file named " + name + " for the effect icon");
	}

	public void AddSEToPrefab(CustomSE customSE, string prefabName)
	{
		SE_Item key = new SE_Item
		{
			Effect = customSE.Effect,
			Type = customSE.Type
		};
		AddToPrefabs.Add(key, prefabName);
	}

	private static ConfigEntry<T> config<T>(string group, string name, T value, ConfigDescription description)
	{
		ConfigEntry<T> configEntry = plugin.Config.Bind(group, name, value, description);
		configSync?.GetType().GetMethod("AddConfigEntry").MakeGenericMethod(typeof(T))
			.Invoke(configSync, new object[1] { configEntry });
		return configEntry;
	}

	private static ConfigEntry<T> config<T>(string group, string name, T value, string description)
	{
		return config(group, name, value, new ConfigDescription(description, null));
	}
}
