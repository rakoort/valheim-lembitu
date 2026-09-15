using System;
using System.Collections;
using System.Collections.Generic;
using System.ComponentModel;
using System.Globalization;
using System.Linq;
using System.Reflection;
using System.Reflection.Emit;
using System.Runtime.CompilerServices;
using System.Text.RegularExpressions;
using BepInEx;
using BepInEx.Bootstrap;
using BepInEx.Configuration;
using HarmonyLib;
using JetBrains.Annotations;
using UnityEngine;

namespace ItemManager;

[PublicAPI]
internal class Item
{
	private class ItemConfig
	{
		public ConfigEntry<string> craft;

		public ConfigEntry<string> upgrade;

		public ConfigEntry<CraftingTable> table;

		public ConfigEntry<int> tableLevel;

		public ConfigEntry<string> customTable;

		public ConfigEntry<int> maximumTableLevel;

		public ConfigEntry<Toggle> requireOneIngredient;

		public ConfigEntry<float> qualityResultAmountMultiplier;
	}

	private class TraderConfig
	{
		public ConfigEntry<Trader> trader;

		public ConfigEntry<uint> price;

		public ConfigEntry<uint> stack;

		public ConfigEntry<string> requiredGlobalKey;
	}

	private class RequirementQuality
	{
		public int quality;
	}

	private class ConfigurationManagerAttributes
	{
		[UsedImplicitly]
		public int? Order;

		[UsedImplicitly]
		public bool? Browsable;

		[UsedImplicitly]
		public string Category;

		[UsedImplicitly]
		public Action<ConfigEntryBase> CustomDrawer;

		public Func<bool> browsability;
	}

	[PublicAPI]
	public enum DamageModifier
	{
		Normal,
		Resistant,
		Weak,
		Immune,
		Ignore,
		VeryResistant,
		VeryWeak,
		None
	}

	private delegate void setDmgFunc(ref HitData.DamageTypes dmg, float value);

	private class SerializedRequirements
	{
		public readonly List<Requirement> Reqs;

		public SerializedRequirements(List<Requirement> reqs)
		{
			Reqs = reqs;
		}

		public SerializedRequirements(string reqs)
			: this(reqs.Split(new char[1] { ',' }).Select((string r) =>
			{
				string[] array = r.Split(new char[1] { ':' });
				int result;
				int result2;
				return new Requirement
				{
					itemName = array[0],
					amount = ((array.Length <= 1 || !int.TryParse(array[1], out result)) ? 1 : result),
					quality = ((array.Length > 2 && int.TryParse(array[2], out result2)) ? result2 : 0)
				};
			}).ToList())
		{
		}

		public override string ToString()
		{
			return string.Join(",", Reqs.Select((Requirement r) => $"{r.itemName}:{r.amount}" + ((r.quality > 0) ? $":{r.quality}" : "")));
		}

		public static ItemDrop fetchByName(ObjectDB objectDB, string name)
		{
			ItemDrop obj = objectDB.GetItemPrefab(name)?.GetComponent<ItemDrop>();
			if (obj == null)
			{
				Debug.LogWarning("The required item '" + name + "' does not exist.");
			}
			return obj;
		}

		public static Piece.Requirement[] toPieceReqs(ObjectDB objectDB, SerializedRequirements craft, SerializedRequirements upgrade)
		{
			Dictionary<string, Piece.Requirement> dictionary = craft.Reqs.Where((Requirement r) => r.itemName != "").ToDictionary((Requirement r) => r.itemName, (Requirement r) =>
			{
				ItemDrop itemDrop3 = ResItem(r);
				return ((object)itemDrop3 == null) ? null : new Piece.Requirement
				{
					m_amount = (r.amountConfig?.Value ?? r.amount),
					m_resItem = itemDrop3,
					m_amountPerLevel = 0
				};
			});
			List<Piece.Requirement> list = dictionary.Values.Where((Piece.Requirement v) => v != null).ToList();
			foreach (Requirement item in upgrade.Reqs.Where((Requirement r) => r.itemName != ""))
			{
				if (item.quality > 0)
				{
					ItemDrop itemDrop = ResItem(item);
					if ((object)itemDrop != null)
					{
						Piece.Requirement requirement = new Piece.Requirement
						{
							m_resItem = itemDrop,
							m_amountPerLevel = (item.amountConfig?.Value ?? item.amount),
							m_amount = 0
						};
						list.Add(requirement);
						requirementQuality.Add(requirement, new RequirementQuality
						{
							quality = item.quality
						});
					}
					continue;
				}
				if (!dictionary.TryGetValue(item.itemName, out var value) || value == null)
				{
					ItemDrop itemDrop2 = ResItem(item);
					if ((object)itemDrop2 != null)
					{
						string itemName = item.itemName;
						Piece.Requirement obj = new Piece.Requirement
						{
							m_resItem = itemDrop2,
							m_amount = 0
						};
						Piece.Requirement requirement2 = obj;
						dictionary[itemName] = obj;
						value = requirement2;
						list.Add(value);
					}
				}
				if (value != null)
				{
					value.m_amountPerLevel = item.amountConfig?.Value ?? item.amount;
				}
			}
			return list.ToArray();
			ItemDrop ResItem(Requirement r)
			{
				return fetchByName(objectDB, r.itemName);
			}
		}
	}

	private class SerializedDrop
	{
		public readonly List<DropTarget> Drops;

		public SerializedDrop(List<DropTarget> drops)
		{
			Drops = drops;
		}

		public SerializedDrop(string drops)
		{
			Drops = ((drops == "") ? ((IEnumerable<string>)Array.Empty<string>()) : ((IEnumerable<string>)drops.Split(new char[1] { ',' }))).Select((string r) =>
			{
				string[] array = r.Split(new char[1] { ':' });
				if (array.Length <= 2 || !int.TryParse(array[2], out var result))
				{
					result = 1;
				}
				if (array.Length <= 3 || !int.TryParse(array[3], out var result2))
				{
					result2 = result;
				}
				bool levelMultiplier = array.Length <= 4 || array[4] != "0";
				float result3;
				return new DropTarget
				{
					creature = array[0],
					chance = ((array.Length > 1 && float.TryParse(array[1], out result3)) ? result3 : 1f),
					min = result,
					max = result2,
					levelMultiplier = levelMultiplier
				};
			}).ToList();
		}

		public override string ToString()
		{
			return string.Join(",", Drops.Select((DropTarget r) => $"{r.creature}:{r.chance.ToString(CultureInfo.InvariantCulture)}:{r.min}:" + ((r.min == r.max) ? "" : $"{r.max}") + (r.levelMultiplier ? "" : ":0")));
		}

		private static Character fetchByName(ZNetScene netScene, string name)
		{
			Character obj = netScene.GetPrefab(name)?.GetComponent<Character>();
			if (obj == null)
			{
				Debug.LogWarning("The drop target character '" + name + "' does not exist.");
			}
			return obj;
		}

		public Dictionary<Character, CharacterDrop.Drop> toCharacterDrops(ZNetScene netScene, GameObject item)
		{
			Dictionary<Character, CharacterDrop.Drop> dictionary = new Dictionary<Character, CharacterDrop.Drop>();
			foreach (DropTarget drop in Drops)
			{
				Character character = fetchByName(netScene, drop.creature);
				if ((object)character != null)
				{
					dictionary[character] = new CharacterDrop.Drop
					{
						m_prefab = item,
						m_amountMin = drop.min,
						m_amountMax = drop.max,
						m_chance = drop.chance,
						m_levelMultiplier = drop.levelMultiplier
					};
				}
			}
			return dictionary;
		}
	}

	private static readonly List<Item> registeredItems = new List<Item>();

	private static readonly Dictionary<ItemDrop, Item> itemDropMap = new Dictionary<ItemDrop, Item>();

	private static Dictionary<Item, Dictionary<string, List<Recipe>>> activeRecipes = new Dictionary<Item, Dictionary<string, List<Recipe>>>();

	private static Dictionary<Recipe, ConfigEntryBase> hiddenCraftRecipes = new Dictionary<Recipe, ConfigEntryBase>();

	private static Dictionary<Recipe, ConfigEntryBase> hiddenUpgradeRecipes = new Dictionary<Recipe, ConfigEntryBase>();

	private static Dictionary<Item, Dictionary<string, ItemConfig>> itemCraftConfigs = new Dictionary<Item, Dictionary<string, ItemConfig>>();

	private static Dictionary<Item, ConfigEntry<string>> itemDropConfigs = new Dictionary<Item, ConfigEntry<string>>();

	private Dictionary<CharacterDrop, CharacterDrop.Drop> characterDrops = new Dictionary<CharacterDrop, CharacterDrop.Drop>();

	private readonly Dictionary<ConfigEntryBase, Action> statsConfigs = new Dictionary<ConfigEntryBase, Action>();

	private static readonly ConditionalWeakTable<Piece.Requirement, RequirementQuality> requirementQuality = new ConditionalWeakTable<Piece.Requirement, RequirementQuality>();

	public static Configurability DefaultConfigurability = Configurability.Full;

	public Configurability? Configurable;

	private Configurability configurationVisible = Configurability.Full;

	private TraderConfig traderConfig;

	public readonly GameObject Prefab;

	[Description("Specifies the maximum required crafting station level to upgrade and repair the item.\nDefault is calculated from crafting station level and maximum quality.")]
	public int MaximumRequiredStationLevel = int.MaxValue;

	[Description("Assigns the item as a drop item to a creature.\nUses a creature name, a drop chance and a minimum and maximum amount.")]
	public readonly DropTargets DropsFrom = new DropTargets();

	[Description("Configures whether the item can be bought at the trader.\nDon't forget to set cost to something above 0 or the item will be sold for free.")]
	public readonly Trade Trade = new Trade();

	internal List<Conversion> Conversions = new List<Conversion>();

	internal List<Smelter.ItemConversion> conversions = new List<Smelter.ItemConversion>();

	public Dictionary<string, ItemRecipe> Recipes = new Dictionary<string, ItemRecipe>();

	private LocalizeKey _name;

	private LocalizeKey _description;

	private static object configManager;

	private static Localization _english;

	private static BaseUnityPlugin _plugin;

	private static bool hasConfigSync = true;

	private static object _configSync;

	private Configurability configurability => Configurable ?? DefaultConfigurability;

	[Description("Specifies the resources needed to craft the item.\nUse .Add to add resources with their internal ID and an amount.\nUse one .Add for each resource type the item should need.")]
	public RequiredResourceList RequiredItems => this[""].RequiredItems;

	[Description("Specifies the resources needed to upgrade the item.\nUse .Add to add resources with their internal ID and an amount. This amount will be multipled by the item quality level.\nUse one .Add for each resource type the upgrade should need.")]
	public RequiredResourceList RequiredUpgradeItems => this[""].RequiredUpgradeItems;

	[Description("Specifies the crafting station needed to craft the item.\nUse .Add to add a crafting station, using the CraftingTable enum and a minimum level for the crafting station.\nUse one .Add for each crafting station.")]
	public CraftingStationList Crafting => this[""].Crafting;

	[Description("Specifies a config entry which toggles whether a recipe is active.")]
	public ConfigEntryBase RecipeIsActive
	{
		get
		{
			return this[""].RecipeIsActive;
		}
		set
		{
			this[""].RecipeIsActive = value;
		}
	}

	[Description("Specifies the number of items that should be given to the player with a single craft of the item.\nDefaults to 1.")]
	public int CraftAmount
	{
		get
		{
			return this[""].CraftAmount;
		}
		set
		{
			this[""].CraftAmount = value;
		}
	}

	public bool RequireOnlyOneIngredient
	{
		get
		{
			return this[""].RequireOnlyOneIngredient;
		}
		set
		{
			this[""].RequireOnlyOneIngredient = value;
		}
	}

	public float QualityResultAmountMultiplier
	{
		get
		{
			return this[""].QualityResultAmountMultiplier;
		}
		set
		{
			this[""].QualityResultAmountMultiplier = value;
		}
	}

	public ItemRecipe this[string name]
	{
		get
		{
			if (Recipes.TryGetValue(name, out var value))
			{
				return value;
			}
			return Recipes[name] = new ItemRecipe();
		}
	}

	public LocalizeKey Name
	{
		get
		{
			LocalizeKey name = _name;
			if (name != null)
			{
				return name;
			}
			ItemDrop.ItemData.SharedData shared = Prefab.GetComponent<ItemDrop>().m_itemData.m_shared;
			if (shared.m_name.StartsWith("$"))
			{
				_name = new LocalizeKey(shared.m_name);
			}
			else
			{
				string text = "$item_" + Prefab.name.Replace(" ", "_");
				_name = new LocalizeKey(text).English(shared.m_name);
				shared.m_name = text;
			}
			return _name;
		}
	}

	public LocalizeKey Description
	{
		get
		{
			LocalizeKey description = _description;
			if (description != null)
			{
				return description;
			}
			ItemDrop.ItemData.SharedData shared = Prefab.GetComponent<ItemDrop>().m_itemData.m_shared;
			if (shared.m_description.StartsWith("$"))
			{
				_description = new LocalizeKey(shared.m_description);
			}
			else
			{
				string text = "$itemdesc_" + Prefab.name.Replace(" ", "_");
				_description = new LocalizeKey(text).English(shared.m_description);
				shared.m_description = text;
			}
			return _description;
		}
	}

	private static Localization english => _english ?? (_english = LocalizationCache.ForLanguage("English"));

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

	public Item(string assetBundleFileName, string prefabName, string folderName = "assets")
		: this(PrefabManager.RegisterAssetBundle(assetBundleFileName, folderName), prefabName)
	{
	}

	public Item(AssetBundle bundle, string prefabName)
		: this(PrefabManager.RegisterPrefab(bundle, prefabName, addToObjectDb: true), skipRegistering: true)
	{
	}

	public Item(GameObject prefab, bool skipRegistering = false)
	{
		if (!skipRegistering)
		{
			PrefabManager.RegisterPrefab(prefab, addToObjectDb: true);
		}
		Prefab = prefab;
		registeredItems.Add(this);
		itemDropMap[Prefab.GetComponent<ItemDrop>()] = this;
		Prefab.GetComponent<ItemDrop>().m_itemData.m_dropPrefab = Prefab;
	}

	public void ToggleConfigurationVisibility(Configurability visible)
	{
		configurationVisible = visible;
		if (itemDropConfigs.TryGetValue(this, out var value))
		{
			Toggle(value, Configurability.Drop);
		}
		if (itemCraftConfigs.TryGetValue(this, out var value2))
		{
			foreach (ItemConfig value3 in value2.Values)
			{
				ToggleObj(value3, Configurability.Recipe);
			}
		}
		foreach (Conversion conversion in Conversions)
		{
			if (conversion.config != null)
			{
				ToggleObj(conversion.config, Configurability.Recipe);
			}
		}
		foreach (KeyValuePair<ConfigEntryBase, Action> statsConfig in statsConfigs)
		{
			Toggle(statsConfig.Key, Configurability.Stats);
			if ((visible & Configurability.Stats) != Configurability.Disabled)
			{
				statsConfig.Value();
			}
		}
		reloadConfigDisplay();
		void Toggle(ConfigEntryBase cfg, Configurability check)
		{
			object[] tags = cfg.Description.Tags;
			for (int i = 0; i < tags.Length; i++)
			{
				if (tags[i] is ConfigurationManagerAttributes configurationManagerAttributes)
				{
					configurationManagerAttributes.Browsable = (visible & check) != Configurability.Disabled && (configurationManagerAttributes.browsability == null || configurationManagerAttributes.browsability());
				}
			}
		}
		void ToggleObj(object obj, Configurability check)
		{
			FieldInfo[] fields = obj.GetType().GetFields();
			for (int i = 0; i < fields.Length; i++)
			{
				if (fields[i].GetValue(obj) is ConfigEntryBase cfg)
				{
					Toggle(cfg, check);
				}
			}
		}
	}

	internal static void reloadConfigDisplay()
	{
		object obj = configManager?.GetType().GetProperty("DisplayingWindow").GetValue(configManager);
		if (obj is bool && (bool)obj)
		{
			configManager.GetType().GetMethod("BuildSettingList").Invoke(configManager, Array.Empty<object>());
		}
	}

	private void UpdateItemTableConfig(string recipeKey, CraftingTable table, string customTableValue)
	{
		if (activeRecipes.ContainsKey(this) && activeRecipes[this].TryGetValue(recipeKey, out var value))
		{
			value.First().m_enabled = table != CraftingTable.Disabled;
			if ((uint)table <= 1u)
			{
				value.First().m_craftingStation = null;
			}
			else if (table == CraftingTable.Custom)
			{
				value.First().m_craftingStation = ZNetScene.instance.GetPrefab(customTableValue)?.GetComponent<CraftingStation>();
			}
			else
			{
				value.First().m_craftingStation = ZNetScene.instance.GetPrefab(getInternalName(table)).GetComponent<CraftingStation>();
			}
		}
	}

	private void UpdateCraftConfig(string recipeKey, SerializedRequirements craftRequirements, SerializedRequirements upgradeRequirements)
	{
		if (!ObjectDB.instance || !activeRecipes.ContainsKey(this) || !activeRecipes[this].TryGetValue(recipeKey, out var value))
		{
			return;
		}
		foreach (Recipe item in value)
		{
			item.m_resources = SerializedRequirements.toPieceReqs(ObjectDB.instance, craftRequirements, upgradeRequirements);
		}
	}

	internal static void Patch_FejdStartup()
	{
		Type type = AppDomain.CurrentDomain.GetAssemblies().FirstOrDefault((Assembly a) => a.GetName().Name == "ConfigurationManager")?.GetType("ConfigurationManager.ConfigurationManager");
		if (DefaultConfigurability != Configurability.Disabled)
		{
			bool saveOnConfigSet = plugin.Config.SaveOnConfigSet;
			plugin.Config.SaveOnConfigSet = false;
			foreach (Item item3 in registeredItems.Where((Item i) => i.configurability != Configurability.Disabled))
			{
				Item item = item3;
				string name = item.Prefab.GetComponent<ItemDrop>().m_itemData.m_shared.m_name;
				string englishName = new Regex("[=\\n\\t\\\\\"\\'\\[\\]]*").Replace(english.Localize(name), "").Trim();
				string localizedName = Localization.instance.Localize(name).Trim();
				int order = 0;
				if ((item.configurability & Configurability.Recipe) != Configurability.Disabled)
				{
					itemCraftConfigs[item] = new Dictionary<string, ItemConfig>();
					foreach (string item4 in item.Recipes.Keys.DefaultIfEmpty(""))
					{
						string configKey = item4;
						string text = ((configKey == "") ? "" : (" (" + configKey + ")"));
						if (!item.Recipes.ContainsKey(configKey) || item.Recipes[configKey].Crafting.Stations.Count <= 0)
						{
							continue;
						}
						ItemConfig itemConfig = (itemCraftConfigs[item][configKey] = new ItemConfig());
						ItemConfig cfg = itemConfig;
						List<ConfigurationManagerAttributes> hideWhenNoneAttributes = new List<ConfigurationManagerAttributes>();
						cfg.table = config(englishName, "Crafting Station" + text, item.Recipes[configKey].Crafting.Stations.First().Table, new ConfigDescription("Crafting station where " + englishName + " is available.", null, new ConfigurationManagerAttributes
						{
							Order = (order -= 1),
							Browsable = ((item.configurationVisible & Configurability.Recipe) != 0),
							Category = localizedName
						}));
						ConfigurationManagerAttributes customTableAttributes = new ConfigurationManagerAttributes
						{
							Order = (order -= 1),
							browsability = CustomTableBrowsability,
							Browsable = (CustomTableBrowsability() && (item.configurationVisible & Configurability.Recipe) != 0),
							Category = localizedName
						};
						cfg.customTable = config(englishName, "Custom Crafting Station" + text, item.Recipes[configKey].Crafting.Stations.First().custom ?? "", new ConfigDescription("", null, customTableAttributes));
						cfg.table.SettingChanged += TableConfigChanged;
						cfg.customTable.SettingChanged += TableConfigChanged;
						ConfigurationManagerAttributes configurationManagerAttributes = new ConfigurationManagerAttributes
						{
							Order = (order -= 1),
							browsability = TableLevelBrowsability,
							Browsable = (TableLevelBrowsability() && (item.configurationVisible & Configurability.Recipe) != 0),
							Category = localizedName
						};
						hideWhenNoneAttributes.Add(configurationManagerAttributes);
						cfg.tableLevel = config(englishName, "Crafting Station Level" + text, item.Recipes[configKey].Crafting.Stations.First().level, new ConfigDescription("Required crafting station level to craft " + englishName + ".", null, configurationManagerAttributes));
						cfg.tableLevel.SettingChanged += (object _, EventArgs _) =>
						{
							if (activeRecipes.ContainsKey(item) && activeRecipes[item].TryGetValue(configKey, out var value))
							{
								value.First().m_minStationLevel = cfg.tableLevel.Value;
							}
						};
						if (item.Prefab.GetComponent<ItemDrop>().m_itemData.m_shared.m_maxQuality > 1)
						{
							cfg.maximumTableLevel = config(englishName, "Maximum Crafting Station Level" + text, (item.MaximumRequiredStationLevel == int.MaxValue) ? (item.Recipes[configKey].Crafting.Stations.First().level + item.Prefab.GetComponent<ItemDrop>().m_itemData.m_shared.m_maxQuality - 1) : item.MaximumRequiredStationLevel, new ConfigDescription("Maximum crafting station level to upgrade and repair " + englishName + ".", null, configurationManagerAttributes));
						}
						cfg.requireOneIngredient = config(englishName, "Require only one resource" + text, item.Recipes[configKey].RequireOnlyOneIngredient ? Toggle.On : Toggle.Off, new ConfigDescription("Whether only one of the ingredients is needed to craft " + englishName, null, new ConfigurationManagerAttributes
						{
							Order = (order -= 1),
							Category = localizedName
						}));
						ConfigurationManagerAttributes qualityResultAttributes = new ConfigurationManagerAttributes
						{
							Order = (order -= 1),
							browsability = QualityResultBrowsability,
							Browsable = (QualityResultBrowsability() && (item.configurationVisible & Configurability.Recipe) != 0),
							Category = localizedName
						};
						cfg.requireOneIngredient.SettingChanged += (object _, EventArgs _) =>
						{
							if (activeRecipes.ContainsKey(item) && activeRecipes[item].TryGetValue(configKey, out var value))
							{
								foreach (Recipe item5 in value)
								{
									item5.m_requireOnlyOneIngredient = cfg.requireOneIngredient.Value == Toggle.On;
								}
							}
							qualityResultAttributes.Browsable = QualityResultBrowsability();
							reloadConfigDisplay();
						};
						cfg.qualityResultAmountMultiplier = config(englishName, "Quality Multiplier" + text, item.Recipes[configKey].QualityResultAmountMultiplier, new ConfigDescription("Multiplies the crafted amount based on the quality of the resources when crafting " + englishName + ". Only works, if Require Only One Resource is true.", null, qualityResultAttributes));
						cfg.qualityResultAmountMultiplier.SettingChanged += (object _, EventArgs _) =>
						{
							if (activeRecipes.ContainsKey(item) && activeRecipes[item].TryGetValue(configKey, out var value))
							{
								foreach (Recipe item6 in value)
								{
									item6.m_qualityResultAmountMultiplier = cfg.qualityResultAmountMultiplier.Value;
								}
							}
						};
						if ((!item.Recipes[configKey].RequiredItems.Free || item.Recipes[configKey].RequiredItems.Requirements.Count > 0) && item.Recipes[configKey].RequiredItems.Requirements.All((Requirement r) => r.amountConfig == null))
						{
							cfg.craft = itemConfig3("Crafting Costs" + text, new SerializedRequirements(item.Recipes[configKey].RequiredItems.Requirements).ToString(), "Item costs to craft " + englishName, isUpgrade: false);
						}
						if (item.Prefab.GetComponent<ItemDrop>().m_itemData.m_shared.m_maxQuality > 1 && (!item.Recipes[configKey].RequiredUpgradeItems.Free || item.Recipes[configKey].RequiredUpgradeItems.Requirements.Count > 0) && item.Recipes[configKey].RequiredUpgradeItems.Requirements.All((Requirement r) => r.amountConfig == null))
						{
							cfg.upgrade = itemConfig3("Upgrading Costs" + text, new SerializedRequirements(item.Recipes[configKey].RequiredUpgradeItems.Requirements).ToString(), "Item costs per level to upgrade " + englishName, isUpgrade: true);
						}
						if (cfg.craft != null)
						{
							cfg.craft.SettingChanged += ConfigChanged;
						}
						if (cfg.upgrade != null)
						{
							cfg.upgrade.SettingChanged += ConfigChanged;
						}
						void ConfigChanged(object o, EventArgs e)
						{
							item.UpdateCraftConfig(configKey, new SerializedRequirements(cfg.craft?.Value ?? ""), new SerializedRequirements(cfg.upgrade?.Value ?? ""));
						}
						bool CustomTableBrowsability()
						{
							return cfg.table.Value == CraftingTable.Custom;
						}
						bool ItemBrowsability()
						{
							return cfg.table.Value != CraftingTable.Disabled;
						}
						bool QualityResultBrowsability()
						{
							return cfg.requireOneIngredient.Value == Toggle.On;
						}
						void TableConfigChanged(object o, EventArgs e)
						{
							item.UpdateItemTableConfig(configKey, cfg.table.Value, cfg.customTable.Value);
							customTableAttributes.Browsable = cfg.table.Value == CraftingTable.Custom;
							foreach (ConfigurationManagerAttributes item7 in hideWhenNoneAttributes)
							{
								item7.Browsable = cfg.table.Value != CraftingTable.Disabled;
							}
							reloadConfigDisplay();
						}
						bool TableLevelBrowsability()
						{
							return cfg.table.Value != CraftingTable.Disabled;
						}
						ConfigEntry<string> itemConfig3(string name2, string value, string desc, bool isUpgrade)
						{
							ConfigurationManagerAttributes configurationManagerAttributes2 = new ConfigurationManagerAttributes
							{
								CustomDrawer = drawRequirementsConfigTable(item, isUpgrade),
								Order = (order -= 1),
								browsability = ItemBrowsability,
								Browsable = (ItemBrowsability() && (item.configurationVisible & Configurability.Recipe) != 0),
								Category = localizedName
							};
							hideWhenNoneAttributes.Add(configurationManagerAttributes2);
							return config(englishName, name2, value, new ConfigDescription(desc, null, configurationManagerAttributes2));
						}
					}
					if ((item.configurability & Configurability.Drop) != Configurability.Disabled)
					{
						ConfigEntry<string> configEntry = (itemDropConfigs[item] = config(englishName, "Drops from", new SerializedDrop(item.DropsFrom.Drops).ToString(), new ConfigDescription(englishName + " drops from this creature.", null, new ConfigurationManagerAttributes
						{
							CustomDrawer = drawDropsConfigTable,
							Category = localizedName,
							Browsable = ((item.configurationVisible & Configurability.Drop) != 0)
						})));
						configEntry.SettingChanged += (object _, EventArgs _) =>
						{
							item.UpdateCharacterDrop();
						};
					}
					for (int num = 0; num < item.Conversions.Count; num++)
					{
						string text2 = ((item.Conversions.Count > 1) ? $"{num + 1}. " : "");
						Conversion conversion = item.Conversions[num];
						conversion.config = new Conversion.ConversionConfig();
						int index = num;
						conversion.config.input = config(englishName, text2 + "Conversion Input Item", conversion.Input, new ConfigDescription("Input item to create " + englishName, null, new ConfigurationManagerAttributes
						{
							Category = localizedName,
							Browsable = ((item.configurationVisible & Configurability.Recipe) != 0)
						}));
						conversion.config.input.SettingChanged += (object _, EventArgs _) =>
						{
							if (index < item.conversions.Count)
							{
								ObjectDB instance = ObjectDB.instance;
								if ((object)instance != null)
								{
									ItemDrop itemDrop = SerializedRequirements.fetchByName(instance, conversion.config.input.Value);
									item.conversions[index].m_from = itemDrop;
									UpdatePiece();
								}
							}
						};
						conversion.config.piece = config(englishName, text2 + "Conversion Piece", conversion.Piece, new ConfigDescription("Conversion piece used to create " + englishName, null, new ConfigurationManagerAttributes
						{
							Category = localizedName,
							Browsable = ((item.configurationVisible & Configurability.Recipe) != 0)
						}));
						conversion.config.piece.SettingChanged += (object _, EventArgs _) =>
						{
							UpdatePiece();
						};
						conversion.config.customPiece = config(englishName, text2 + "Conversion Custom Piece", conversion.customPiece ?? "", new ConfigDescription("Custom conversion piece to create " + englishName, null, new ConfigurationManagerAttributes
						{
							Category = localizedName,
							Browsable = ((item.configurationVisible & Configurability.Recipe) != 0)
						}));
						conversion.config.customPiece.SettingChanged += (object _, EventArgs _) =>
						{
							UpdatePiece();
						};
						void UpdatePiece()
						{
							if (index < item.conversions.Count && (bool)ZNetScene.instance)
							{
								string text3 = ((conversion.config.piece.Value == ConversionPiece.Disabled) ? null : ((conversion.config.piece.Value == ConversionPiece.Custom) ? conversion.config.customPiece.Value : getInternalName(conversion.config.piece.Value)));
								string activePiece = conversion.config.activePiece;
								if (conversion.config.activePiece != null)
								{
									int num4 = ZNetScene.instance.GetPrefab(conversion.config.activePiece).GetComponent<Smelter>().m_conversion.IndexOf(item.conversions[index]);
									if (num4 >= 0)
									{
										Smelter[] array2 = Resources.FindObjectsOfTypeAll<Smelter>();
										foreach (Smelter smelter in array2)
										{
											if (Utils.GetPrefabName(smelter.gameObject) == activePiece)
											{
												smelter.m_conversion.RemoveAt(num4);
											}
										}
									}
									conversion.config.activePiece = null;
								}
								if ((object)item.conversions[index].m_from != null && conversion.config.piece.Value != ConversionPiece.Disabled && (object)ZNetScene.instance.GetPrefab(text3)?.GetComponent<Smelter>() != null)
								{
									conversion.config.activePiece = text3;
									Smelter[] array2 = Resources.FindObjectsOfTypeAll<Smelter>();
									foreach (Smelter smelter2 in array2)
									{
										if (Utils.GetPrefabName(smelter2.gameObject) == text3)
										{
											smelter2.m_conversion.Add(item.conversions[index]);
										}
									}
								}
							}
						}
					}
				}
				if ((item.configurability & Configurability.Stats) != Configurability.Disabled)
				{
					item.statsConfigs.Clear();
					ItemDrop.ItemData.SharedData shared = item.Prefab.GetComponent<ItemDrop>().m_itemData.m_shared;
					ItemDrop.ItemData.ItemType itemType = shared.m_itemType;
					statcfg<float>("Weight", "Weight of " + englishName + ".", (ItemDrop.ItemData.SharedData sharedData) => sharedData.m_weight, delegate(ItemDrop.ItemData.SharedData sharedData, float value)
					{
						sharedData.m_weight = value;
					});
					statcfg<int>("Trader Value", "Trader value of " + englishName + ".", (ItemDrop.ItemData.SharedData sharedData) => sharedData.m_value, delegate(ItemDrop.ItemData.SharedData sharedData, int value)
					{
						sharedData.m_value = value;
					});
					bool flag;
					switch (itemType)
					{
					case ItemDrop.ItemData.ItemType.OneHandedWeapon:
					case ItemDrop.ItemData.ItemType.Bow:
					case ItemDrop.ItemData.ItemType.Shield:
					case ItemDrop.ItemData.ItemType.Helmet:
					case ItemDrop.ItemData.ItemType.Chest:
					case ItemDrop.ItemData.ItemType.Legs:
					case ItemDrop.ItemData.ItemType.Hands:
					case ItemDrop.ItemData.ItemType.TwoHandedWeapon:
					case ItemDrop.ItemData.ItemType.Shoulder:
					case ItemDrop.ItemData.ItemType.Tool:
					case ItemDrop.ItemData.ItemType.TwoHandedWeaponLeft:
						flag = true;
						break;
					default:
						flag = false;
						break;
					}
					if (flag)
					{
						statcfg<float>("Durability", "Durability of " + englishName + ".", (ItemDrop.ItemData.SharedData sharedData) => sharedData.m_maxDurability, delegate(ItemDrop.ItemData.SharedData sharedData, float value)
						{
							sharedData.m_maxDurability = value;
						});
						statcfg<float>("Durability per Level", "Durability gain per level of " + englishName + ".", (ItemDrop.ItemData.SharedData sharedData) => sharedData.m_durabilityPerLevel, delegate(ItemDrop.ItemData.SharedData sharedData, float value)
						{
							sharedData.m_durabilityPerLevel = value;
						});
						statcfg<float>("Movement Speed Modifier", "Movement speed modifier of " + englishName + ".", (ItemDrop.ItemData.SharedData sharedData) => sharedData.m_movementModifier, delegate(ItemDrop.ItemData.SharedData sharedData, float value)
						{
							sharedData.m_movementModifier = value;
						});
					}
					if (((uint)(itemType - 3) <= 2u || itemType == ItemDrop.ItemData.ItemType.TwoHandedWeapon || itemType == ItemDrop.ItemData.ItemType.TwoHandedWeaponLeft) ? true : false)
					{
						statcfg<float>("Block Armor", "Block armor of " + englishName + ".", (ItemDrop.ItemData.SharedData sharedData) => sharedData.m_blockPower, delegate(ItemDrop.ItemData.SharedData sharedData, float value)
						{
							sharedData.m_blockPower = value;
						});
						statcfg<float>("Block Armor per Level", "Block armor per level for " + englishName + ".", (ItemDrop.ItemData.SharedData sharedData) => sharedData.m_blockPowerPerLevel, delegate(ItemDrop.ItemData.SharedData sharedData, float value)
						{
							sharedData.m_blockPowerPerLevel = value;
						});
						statcfg<float>("Block Force", "Block force of " + englishName + ".", (ItemDrop.ItemData.SharedData sharedData) => sharedData.m_deflectionForce, delegate(ItemDrop.ItemData.SharedData sharedData, float value)
						{
							sharedData.m_deflectionForce = value;
						});
						statcfg<float>("Block Force per Level", "Block force per level for " + englishName + ".", (ItemDrop.ItemData.SharedData sharedData) => sharedData.m_deflectionForcePerLevel, delegate(ItemDrop.ItemData.SharedData sharedData, float value)
						{
							sharedData.m_deflectionForcePerLevel = value;
						});
						statcfg<float>("Parry Bonus", "Parry bonus of " + englishName + ".", (ItemDrop.ItemData.SharedData sharedData) => sharedData.m_timedBlockBonus, delegate(ItemDrop.ItemData.SharedData sharedData, float value)
						{
							sharedData.m_timedBlockBonus = value;
						});
					}
					else if (((uint)(itemType - 6) <= 1u || (uint)(itemType - 11) <= 1u || itemType == ItemDrop.ItemData.ItemType.Shoulder) ? true : false)
					{
						statcfg<float>("Armor", "Armor of " + englishName + ".", (ItemDrop.ItemData.SharedData sharedData) => sharedData.m_armor, delegate(ItemDrop.ItemData.SharedData sharedData, float value)
						{
							sharedData.m_armor = value;
						});
						statcfg<float>("Armor per Level", "Armor per level for " + englishName + ".", (ItemDrop.ItemData.SharedData sharedData) => sharedData.m_armorPerLevel, delegate(ItemDrop.ItemData.SharedData sharedData, float value)
						{
							sharedData.m_armorPerLevel = value;
						});
					}
					Skills.SkillType skillType = shared.m_skillType;
					if ((skillType == Skills.SkillType.Axes || skillType == Skills.SkillType.Pickaxes) ? true : false)
					{
						statcfg<int>("Tool tier", "Tool tier of " + englishName + ".", (ItemDrop.ItemData.SharedData sharedData) => sharedData.m_toolTier, delegate(ItemDrop.ItemData.SharedData sharedData, int value)
						{
							sharedData.m_toolTier = value;
						});
					}
					if (((uint)(itemType - 5) <= 2u || (uint)(itemType - 11) <= 1u || itemType == ItemDrop.ItemData.ItemType.Shoulder) ? true : false)
					{
						Dictionary<HitData.DamageType, DamageModifier> modifiers = shared.m_damageModifiers.ToDictionary((HitData.DamageModPair d) => d.m_type, (HitData.DamageModPair d) => (DamageModifier)d.m_modifier);
						foreach (HitData.DamageType damageType in ((HitData.DamageType[])Enum.GetValues(typeof(HitData.DamageType))).Except(new HitData.DamageType[5]
						{
							HitData.DamageType.Chop,
							HitData.DamageType.Pickaxe,
							HitData.DamageType.Spirit,
							HitData.DamageType.Physical,
							HitData.DamageType.Elemental
						}))
						{
							statcfg<DamageModifier>(damageType.ToString() + " Resistance", damageType.ToString() + " resistance of " + englishName + ".", (ItemDrop.ItemData.SharedData _) => (!modifiers.TryGetValue(damageType, out var value)) ? DamageModifier.None : value, delegate(ItemDrop.ItemData.SharedData sharedData, DamageModifier value)
							{
								HitData.DamageModPair damageModPair = new HitData.DamageModPair
								{
									m_type = damageType,
									m_modifier = (HitData.DamageModifier)value
								};
								for (int i = 0; i < sharedData.m_damageModifiers.Count; i++)
								{
									if (sharedData.m_damageModifiers[i].m_type == damageType)
									{
										if (value == DamageModifier.None)
										{
											sharedData.m_damageModifiers.RemoveAt(i);
										}
										else
										{
											sharedData.m_damageModifiers[i] = damageModPair;
										}
										return;
									}
								}
								if (value != DamageModifier.None)
								{
									sharedData.m_damageModifiers.Add(damageModPair);
								}
							});
						}
					}
					if (itemType == ItemDrop.ItemData.ItemType.Consumable && shared.m_food > 0f)
					{
						statcfg<float>("Health", "Health value of " + englishName + ".", (ItemDrop.ItemData.SharedData sharedData) => sharedData.m_food, delegate(ItemDrop.ItemData.SharedData sharedData, float value)
						{
							sharedData.m_food = value;
						});
						statcfg<float>("Stamina", "Stamina value of " + englishName + ".", (ItemDrop.ItemData.SharedData sharedData) => sharedData.m_foodStamina, delegate(ItemDrop.ItemData.SharedData sharedData, float value)
						{
							sharedData.m_foodStamina = value;
						});
						statcfg<float>("Eitr", "Eitr value of " + englishName + ".", (ItemDrop.ItemData.SharedData sharedData) => sharedData.m_foodEitr, delegate(ItemDrop.ItemData.SharedData sharedData, float value)
						{
							sharedData.m_foodEitr = value;
						});
						statcfg<float>("Duration", "Duration of " + englishName + ".", (ItemDrop.ItemData.SharedData sharedData) => sharedData.m_foodBurnTime, delegate(ItemDrop.ItemData.SharedData sharedData, float value)
						{
							sharedData.m_foodBurnTime = value;
						});
						statcfg<float>("Health Regen", "Health regen value of " + englishName + ".", (ItemDrop.ItemData.SharedData sharedData) => sharedData.m_foodRegen, delegate(ItemDrop.ItemData.SharedData sharedData, float value)
						{
							sharedData.m_foodRegen = value;
						});
					}
					if (shared.m_skillType == Skills.SkillType.BloodMagic)
					{
						statcfg<float>("Health Cost", "Health cost of " + englishName + ".", (ItemDrop.ItemData.SharedData sharedData) => sharedData.m_attack.m_attackHealth, delegate(ItemDrop.ItemData.SharedData sharedData, float value)
						{
							sharedData.m_attack.m_attackHealth = value;
						});
						statcfg<float>("Health Cost Percentage", "Health cost percentage of " + englishName + ".", (ItemDrop.ItemData.SharedData sharedData) => sharedData.m_attack.m_attackHealthPercentage, delegate(ItemDrop.ItemData.SharedData sharedData, float value)
						{
							sharedData.m_attack.m_attackHealthPercentage = value;
						});
					}
					skillType = shared.m_skillType;
					if ((uint)(skillType - 9) <= 1u)
					{
						statcfg<float>("Eitr Cost", "Eitr cost of " + englishName + ".", (ItemDrop.ItemData.SharedData sharedData) => sharedData.m_attack.m_attackEitr, delegate(ItemDrop.ItemData.SharedData sharedData, float value)
						{
							sharedData.m_attack.m_attackEitr = value;
						});
					}
					if (((uint)(itemType - 3) <= 1u || itemType == ItemDrop.ItemData.ItemType.TwoHandedWeapon || itemType == ItemDrop.ItemData.ItemType.TwoHandedWeaponLeft) ? true : false)
					{
						statcfg<float>("Knockback", "Knockback of " + englishName + ".", (ItemDrop.ItemData.SharedData sharedData) => sharedData.m_attackForce, delegate(ItemDrop.ItemData.SharedData sharedData, float value)
						{
							sharedData.m_attackForce = value;
						});
						statcfg<float>("Backstab Bonus", "Backstab bonus of " + englishName + ".", (ItemDrop.ItemData.SharedData sharedData) => sharedData.m_backstabBonus, delegate(ItemDrop.ItemData.SharedData sharedData, float value)
						{
							sharedData.m_backstabBonus = value;
						});
						statcfg<float>("Attack Stamina", "Attack stamina of " + englishName + ".", (ItemDrop.ItemData.SharedData sharedData) => sharedData.m_attack.m_attackStamina, delegate(ItemDrop.ItemData.SharedData sharedData, float value)
						{
							sharedData.m_attack.m_attackStamina = value;
						});
						SetDmg("True", (HitData.DamageTypes dmg) => dmg.m_damage, delegate(ref HitData.DamageTypes dmg, float val)
						{
							dmg.m_damage = val;
						});
						SetDmg("Slash", (HitData.DamageTypes dmg) => dmg.m_slash, delegate(ref HitData.DamageTypes dmg, float val)
						{
							dmg.m_slash = val;
						});
						SetDmg("Pierce", (HitData.DamageTypes dmg) => dmg.m_pierce, delegate(ref HitData.DamageTypes dmg, float val)
						{
							dmg.m_pierce = val;
						});
						SetDmg("Blunt", (HitData.DamageTypes dmg) => dmg.m_blunt, delegate(ref HitData.DamageTypes dmg, float val)
						{
							dmg.m_blunt = val;
						});
						SetDmg("Chop", (HitData.DamageTypes dmg) => dmg.m_chop, delegate(ref HitData.DamageTypes dmg, float val)
						{
							dmg.m_chop = val;
						});
						SetDmg("Pickaxe", (HitData.DamageTypes dmg) => dmg.m_pickaxe, delegate(ref HitData.DamageTypes dmg, float val)
						{
							dmg.m_pickaxe = val;
						});
						SetDmg("Fire", (HitData.DamageTypes dmg) => dmg.m_fire, delegate(ref HitData.DamageTypes dmg, float val)
						{
							dmg.m_fire = val;
						});
						SetDmg("Poison", (HitData.DamageTypes dmg) => dmg.m_poison, delegate(ref HitData.DamageTypes dmg, float val)
						{
							dmg.m_poison = val;
						});
						SetDmg("Frost", (HitData.DamageTypes dmg) => dmg.m_frost, delegate(ref HitData.DamageTypes dmg, float val)
						{
							dmg.m_frost = val;
						});
						SetDmg("Lightning", (HitData.DamageTypes dmg) => dmg.m_lightning, delegate(ref HitData.DamageTypes dmg, float val)
						{
							dmg.m_lightning = val;
						});
						SetDmg("Spirit", (HitData.DamageTypes dmg) => dmg.m_spirit, delegate(ref HitData.DamageTypes dmg, float val)
						{
							dmg.m_spirit = val;
						});
						if (itemType == ItemDrop.ItemData.ItemType.Bow)
						{
							statcfg<int>("Projectiles", "Number of projectiles that " + englishName + " shoots at once.", (ItemDrop.ItemData.SharedData sharedData) => sharedData.m_attack.m_projectileBursts, delegate(ItemDrop.ItemData.SharedData sharedData, int value)
							{
								sharedData.m_attack.m_projectileBursts = value;
							});
							statcfg<float>("Burst Interval", "Time between the projectiles " + englishName + " shoots at once.", (ItemDrop.ItemData.SharedData sharedData) => sharedData.m_attack.m_burstInterval, delegate(ItemDrop.ItemData.SharedData sharedData, float value)
							{
								sharedData.m_attack.m_burstInterval = value;
							});
							statcfg<float>("Minimum Accuracy", "Minimum accuracy for " + englishName + ".", (ItemDrop.ItemData.SharedData sharedData) => sharedData.m_attack.m_projectileAccuracyMin, delegate(ItemDrop.ItemData.SharedData sharedData, float value)
							{
								sharedData.m_attack.m_projectileAccuracyMin = value;
							});
							statcfg<float>("Accuracy", "Accuracy for " + englishName + ".", (ItemDrop.ItemData.SharedData sharedData) => sharedData.m_attack.m_projectileAccuracy, delegate(ItemDrop.ItemData.SharedData sharedData, float value)
							{
								sharedData.m_attack.m_projectileAccuracy = value;
							});
							statcfg<float>("Minimum Velocity", "Minimum velocity for " + englishName + ".", (ItemDrop.ItemData.SharedData sharedData) => sharedData.m_attack.m_projectileVelMin, delegate(ItemDrop.ItemData.SharedData sharedData, float value)
							{
								sharedData.m_attack.m_projectileVelMin = value;
							});
							statcfg<float>("Velocity", "Velocity for " + englishName + ".", (ItemDrop.ItemData.SharedData sharedData) => sharedData.m_attack.m_projectileVel, delegate(ItemDrop.ItemData.SharedData sharedData, float value)
							{
								sharedData.m_attack.m_projectileVel = value;
							});
							statcfg<float>("Maximum Draw Time", "Time until " + englishName + " is fully drawn at skill level 0.", (ItemDrop.ItemData.SharedData sharedData) => sharedData.m_attack.m_drawDurationMin, delegate(ItemDrop.ItemData.SharedData sharedData, float value)
							{
								sharedData.m_attack.m_drawDurationMin = value;
							});
							statcfg<float>("Stamina Drain", "Stamina drain per second while drawing " + englishName + ".", (ItemDrop.ItemData.SharedData sharedData) => sharedData.m_attack.m_drawStaminaDrain, delegate(ItemDrop.ItemData.SharedData sharedData, float value)
							{
								sharedData.m_attack.m_drawStaminaDrain = value;
							});
						}
					}
				}
				List<ConfigurationManagerAttributes> traderAttributes;
				if ((item.configurability & Configurability.Trader) != Configurability.Disabled)
				{
					traderAttributes = new List<ConfigurationManagerAttributes>();
					item.traderConfig = new TraderConfig
					{
						trader = config(englishName, "Trader Selling", item.Trade.Trader, new ConfigDescription("Which traders sell " + englishName + ".", null, new ConfigurationManagerAttributes
						{
							Order = (order -= 1),
							Browsable = ((item.configurationVisible & Configurability.Trader) != 0),
							Category = localizedName
						}))
					};
					item.traderConfig.trader.SettingChanged += (object _, EventArgs _) =>
					{
						item.ReloadTraderConfiguration();
						foreach (ConfigurationManagerAttributes item8 in traderAttributes)
						{
							item8.Browsable = TraderBrowsability();
						}
						reloadConfigDisplay();
					};
					item.traderConfig.price = traderConfig<uint>("Trader Price", item.Trade.Price, "Price of " + englishName + " at the trader.");
					item.traderConfig.stack = traderConfig<uint>("Trader Stack", item.Trade.Stack, "Stack size of " + englishName + " in the trader. Also known as the number of items sold by a trader in one transaction.");
					item.traderConfig.requiredGlobalKey = traderConfig<string>("Trader Required Global Key", item.Trade.RequiredGlobalKey ?? "", "Required global key to unlock " + englishName + " at the trader.");
					if (item.traderConfig.trader.Value != Trader.None)
					{
						PrefabManager.AddItemToTrader(item.Prefab, item.traderConfig.trader.Value, item.traderConfig.price.Value, item.traderConfig.stack.Value, item.traderConfig.requiredGlobalKey.Value);
					}
				}
				else if (item.Trade.Trader != Trader.None)
				{
					PrefabManager.AddItemToTrader(item.Prefab, item.Trade.Trader, item.Trade.Price, item.Trade.Stack, item.Trade.RequiredGlobalKey);
				}
				void SetDmg(string dmgType, Func<HitData.DamageTypes, float> readDmg, setDmgFunc setDmg)
				{
					statcfg<float>(dmgType + " Damage", dmgType + " damage dealt by " + englishName + ".", (ItemDrop.ItemData.SharedData sharedData) => readDmg(sharedData.m_damages), delegate(ItemDrop.ItemData.SharedData sharedData, float val)
					{
						setDmg(ref sharedData.m_damages, val);
					});
					statcfg<float>(dmgType + " Damage Per Level", dmgType + " damage dealt increase per level for " + englishName + ".", (ItemDrop.ItemData.SharedData sharedData) => readDmg(sharedData.m_damagesPerLevel), delegate(ItemDrop.ItemData.SharedData sharedData, float val)
					{
						setDmg(ref sharedData.m_damagesPerLevel, val);
					});
				}
				bool TraderBrowsability()
				{
					return item.traderConfig.trader.Value != Trader.None;
				}
				void statcfg<T>(string configName, string description, Func<ItemDrop.ItemData.SharedData, T> readDefault, Action<ItemDrop.ItemData.SharedData, T> setValue)
				{
					ItemDrop.ItemData.SharedData shared2 = item.Prefab.GetComponent<ItemDrop>().m_itemData.m_shared;
					ConfigEntry<T> cfg2 = config(englishName, configName, readDefault(shared2), new ConfigDescription(description, null, new ConfigurationManagerAttributes
					{
						Category = localizedName,
						Browsable = ((item.configurationVisible & Configurability.Stats) != 0)
					}));
					if ((item.configurationVisible & Configurability.Stats) != Configurability.Disabled)
					{
						setValue(shared2, cfg2.Value);
					}
					item.statsConfigs.Add(cfg2, ApplyConfig);
					cfg2.SettingChanged += (object _, EventArgs _) =>
					{
						if ((item.configurationVisible & Configurability.Stats) != Configurability.Disabled)
						{
							ApplyConfig();
						}
					};
					void ApplyConfig()
					{
						item.ApplyToAllInstances(delegate(ItemDrop.ItemData itemData)
						{
							setValue(itemData.m_shared, cfg2.Value);
						});
					}
				}
				ConfigEntry<T> traderConfig<T>(string name2, T value, string desc)
				{
					ConfigurationManagerAttributes configurationManagerAttributes2 = new ConfigurationManagerAttributes
					{
						Order = (order -= 1),
						browsability = TraderBrowsability,
						Browsable = (TraderBrowsability() && (item.configurationVisible & Configurability.Trader) != 0),
						Category = localizedName
					};
					traderAttributes.Add(configurationManagerAttributes2);
					ConfigEntry<T> configEntry3 = config(englishName, name2, value, new ConfigDescription(desc, null, configurationManagerAttributes2));
					configEntry3.SettingChanged += (object _, EventArgs _) =>
					{
						item.ReloadTraderConfiguration();
					};
					return configEntry3;
				}
			}
			if (saveOnConfigSet)
			{
				plugin.Config.SaveOnConfigSet = true;
				plugin.Config.Save();
			}
		}
		configManager = ((type == null) ? null : Chainloader.ManagerObject.GetComponent(type));
		foreach (Item registeredItem in registeredItems)
		{
			Item item2 = registeredItem;
			foreach (KeyValuePair<string, ItemRecipe> recipe in item2.Recipes)
			{
				KeyValuePair<string, ItemRecipe> kv = recipe;
				RequiredResourceList[] array = new RequiredResourceList[2]
				{
					kv.Value.RequiredItems,
					kv.Value.RequiredUpgradeItems
				};
				foreach (RequiredResourceList requiredResourceList in array)
				{
					for (int num3 = 0; num3 < requiredResourceList.Requirements.Count; num3++)
					{
						ConfigEntry<int> amountCfg;
						int resourceIndex;
						if ((item2.configurability & Configurability.Recipe) != Configurability.Disabled)
						{
							amountCfg = requiredResourceList.Requirements[num3].amountConfig;
							if (amountCfg != null)
							{
								resourceIndex = num3;
								amountCfg.SettingChanged += ConfigChanged2;
							}
						}
						void ConfigChanged2(object o, EventArgs e)
						{
							if ((bool)ObjectDB.instance && activeRecipes.ContainsKey(item2) && activeRecipes[item2].TryGetValue(kv.Key, out var value))
							{
								foreach (Recipe item9 in value)
								{
									item9.m_resources[resourceIndex].m_amount = amountCfg.Value;
								}
							}
						}
					}
				}
			}
			item2.InitializeNewRegisteredItem();
		}
	}

	private void InitializeNewRegisteredItem()
	{
		foreach (KeyValuePair<string, ItemRecipe> recipe in Recipes)
		{
			KeyValuePair<string, ItemRecipe> kv = recipe;
			ConfigEntryBase enabledCfg = kv.Value.RecipeIsActive;
			if (enabledCfg != null)
			{
				enabledCfg.GetType().GetEvent("SettingChanged").AddEventHandler(enabledCfg, new EventHandler(ConfigChanged));
			}
			void ConfigChanged(object o, EventArgs e)
			{
				if ((bool)ObjectDB.instance && activeRecipes.ContainsKey(this) && activeRecipes[this].TryGetValue(kv.Key, out var value))
				{
					foreach (Recipe item in value)
					{
						item.m_enabled = (int)enabledCfg.BoxedValue != 0;
					}
				}
			}
		}
	}

	public void ReloadCraftingConfiguration()
	{
		if ((bool)ObjectDB.instance && (object)ObjectDB.instance.GetItemPrefab(Prefab.name.GetStableHashCode()) == null)
		{
			registerRecipesInObjectDB(ObjectDB.instance);
			ObjectDB.instance.m_items.Add(Prefab);
			ObjectDB.instance.m_itemByHash.Add(Prefab.name.GetStableHashCode(), Prefab);
			ZNetScene.instance.m_prefabs.Add(Prefab);
			ZNetScene.instance.m_namedPrefabs.Add(Prefab.name.GetStableHashCode(), Prefab);
		}
		foreach (string item in Recipes.Keys.DefaultIfEmpty(""))
		{
			if (Recipes.TryGetValue(item, out var value) && value.Crafting.Stations.Count > 0)
			{
				UpdateItemTableConfig(item, value.Crafting.Stations.First().Table, value.Crafting.Stations.First().custom ?? "");
				UpdateCraftConfig(item, new SerializedRequirements(value.RequiredItems.Requirements), new SerializedRequirements(value.RequiredUpgradeItems.Requirements));
			}
		}
	}

	private void ReloadTraderConfiguration()
	{
		if (traderConfig.trader.Value == Trader.None)
		{
			PrefabManager.RemoveItemFromTrader(Prefab);
		}
		else
		{
			PrefabManager.AddItemToTrader(Prefab, traderConfig.trader.Value, traderConfig.price.Value, traderConfig.stack.Value, traderConfig.requiredGlobalKey.Value);
		}
	}

	public static void ApplyToAllInstances(GameObject prefab, Action<ItemDrop.ItemData> callback)
	{
		callback(prefab.GetComponent<ItemDrop>().m_itemData);
		string name = prefab.GetComponent<ItemDrop>().m_itemData.m_shared.m_name;
		Inventory[] source = (from c in Player.s_players.Select((Player p) => p.GetInventory()).Concat(from c in UnityEngine.Object.FindObjectsOfType<Container>()
				select c.GetInventory())
			where c != null
			select c).ToArray();
		foreach (ItemDrop.ItemData item in (from i in (from p in ObjectDB.instance.m_items
				select p.GetComponent<ItemDrop>() into c
				where (bool)c && (bool)c.GetComponent<ZNetView>()
				select c).Concat(ItemDrop.s_instances)
			select i.m_itemData).Concat(source.SelectMany((Inventory i) => i.GetAllItems())))
		{
			if (item.m_shared.m_name == name)
			{
				callback(item);
			}
		}
	}

	public void ApplyToAllInstances(Action<ItemDrop.ItemData> callback)
	{
		ApplyToAllInstances(Prefab, callback);
	}

	private static string getInternalName<T>(T value) where T : struct
	{
		return ((InternalName)typeof(T).GetMember(value.ToString())[0].GetCustomAttributes(typeof(InternalName)).First()).internalName;
	}

	private void registerRecipesInObjectDB(ObjectDB objectDB)
	{
		activeRecipes[this] = new Dictionary<string, List<Recipe>>();
		itemCraftConfigs.TryGetValue(this, out var value);
		foreach (KeyValuePair<string, ItemRecipe> recipe2 in Recipes)
		{
			List<Recipe> list = new List<Recipe>();
			foreach (CraftingStationConfig station in recipe2.Value.Crafting.Stations)
			{
				ItemConfig itemConfig = value?[recipe2.Key];
				Recipe recipe = ScriptableObject.CreateInstance<Recipe>();
				string name = Prefab.name;
				CraftingTable table = station.Table;
				recipe.name = name + "_Recipe_" + table;
				recipe.m_amount = recipe2.Value.CraftAmount;
				recipe.m_enabled = ((itemConfig == null) ? ((int)(recipe2.Value.RecipeIsActive?.BoxedValue ?? ((object)1)) != 0) : (itemConfig.table.Value != CraftingTable.Disabled));
				recipe.m_item = Prefab.GetComponent<ItemDrop>();
				recipe.m_resources = SerializedRequirements.toPieceReqs(objectDB, (itemConfig?.craft == null) ? new SerializedRequirements(recipe2.Value.RequiredItems.Requirements) : new SerializedRequirements(itemConfig.craft.Value), (itemConfig?.upgrade == null) ? new SerializedRequirements(recipe2.Value.RequiredUpgradeItems.Requirements) : new SerializedRequirements(itemConfig.upgrade.Value));
				table = ((itemConfig == null || list.Count > 0) ? station.Table : itemConfig.table.Value);
				if ((uint)table <= 1u)
				{
					recipe.m_craftingStation = null;
				}
				else if (((itemConfig == null || list.Count > 0) ? station.Table : itemConfig.table.Value) == CraftingTable.Custom)
				{
					GameObject prefab = ZNetScene.instance.GetPrefab((itemConfig == null || list.Count > 0) ? station.custom : itemConfig.customTable.Value);
					if ((object)prefab != null)
					{
						recipe.m_craftingStation = prefab.GetComponent<CraftingStation>();
					}
					else
					{
						Debug.LogWarning("Custom crafting station '" + ((itemConfig == null || list.Count > 0) ? station.custom : itemConfig.customTable.Value) + "' does not exist");
					}
				}
				else
				{
					recipe.m_craftingStation = ZNetScene.instance.GetPrefab(getInternalName((itemConfig == null || list.Count > 0) ? station.Table : itemConfig.table.Value)).GetComponent<CraftingStation>();
				}
				recipe.m_minStationLevel = ((itemConfig == null || list.Count > 0) ? station.level : itemConfig.tableLevel.Value);
				recipe.m_requireOnlyOneIngredient = ((itemConfig == null) ? recipe2.Value.RequireOnlyOneIngredient : (itemConfig.requireOneIngredient.Value == Toggle.On));
				recipe.m_qualityResultAmountMultiplier = itemConfig?.qualityResultAmountMultiplier.Value ?? recipe2.Value.QualityResultAmountMultiplier;
				list.Add(recipe);
				RequiredResourceList requiredItems = recipe2.Value.RequiredItems;
				if (requiredItems != null && !requiredItems.Free)
				{
					List<Requirement> requirements = requiredItems.Requirements;
					if (requirements != null && requirements.Count == 0)
					{
						hiddenCraftRecipes.Add(recipe, recipe2.Value.RecipeIsActive);
					}
				}
				requiredItems = recipe2.Value.RequiredUpgradeItems;
				if (requiredItems != null && !requiredItems.Free)
				{
					List<Requirement> requirements = requiredItems.Requirements;
					if (requirements != null && requirements.Count == 0)
					{
						hiddenUpgradeRecipes.Add(recipe, recipe2.Value.RecipeIsActive);
					}
				}
			}
			activeRecipes[this].Add(recipe2.Key, list);
			objectDB.m_recipes.AddRange(list);
		}
		conversions = new List<Smelter.ItemConversion>();
		for (int i = 0; i < Conversions.Count; i++)
		{
			Conversion conversion = Conversions[i];
			conversions.Add(new Smelter.ItemConversion
			{
				m_from = SerializedRequirements.fetchByName(ObjectDB.instance, conversion.config?.input.Value ?? conversion.Input),
				m_to = Prefab.GetComponent<ItemDrop>()
			});
			ConversionPiece conversionPiece = conversion.config?.piece.Value ?? conversion.Piece;
			string text = null;
			if (conversionPiece != ConversionPiece.Disabled && (object)conversions[i].m_from != null)
			{
				text = ((conversionPiece != ConversionPiece.Custom) ? getInternalName(conversionPiece) : (conversion.config?.customPiece.Value ?? conversion.customPiece));
				Smelter smelter = ZNetScene.instance.GetPrefab(text)?.GetComponent<Smelter>();
				if ((object)smelter != null)
				{
					smelter.m_conversion.Add(conversions[i]);
				}
				else
				{
					text = null;
				}
			}
			if (conversion.config != null)
			{
				conversion.config.activePiece = text;
			}
		}
	}

	[HarmonyPriority(0)]
	internal static void Patch_ObjectDBInit(ObjectDB __instance)
	{
		if (__instance.GetItemPrefab("YagluthDrop") == null)
		{
			return;
		}
		hiddenCraftRecipes.Clear();
		hiddenUpgradeRecipes.Clear();
		foreach (Item registeredItem in registeredItems)
		{
			registeredItem.registerRecipesInObjectDB(__instance);
		}
	}

	internal static void Patch_TraderGetAvailableItems(global::Trader __instance, ref List<global::Trader.TradeItem> __result)
	{
		string prefabName = Utils.GetPrefabName(__instance.gameObject);
		Trader trader = ((prefabName == "Haldor") ? Trader.Haldor : ((prefabName == "Hildir") ? Trader.Hildir : Trader.None));
		Trader trader2 = trader;
		__result.AddRange(from tuple in PrefabManager.CustomTradeItems.Values
			where (tuple.Item1 & trader2) != 0
			select tuple.Item2 into tradeItem
			where string.IsNullOrEmpty(tradeItem.m_requiredGlobalKey) || ZoneSystem.instance.GetGlobalKey(tradeItem.m_requiredGlobalKey)
			select tradeItem);
	}

	internal static void Patch_OnAddSmelterInput(ItemDrop.ItemData item, bool __result)
	{
		if (__result)
		{
			Player.m_localPlayer.UnequipItem(item);
		}
	}

	internal static void Patch_MaximumRequiredStationLevel(Recipe __instance, ref int __result, int quality)
	{
		if (!itemDropMap.TryGetValue(__instance.m_item, out var value))
		{
			return;
		}
		IEnumerable<ItemConfig> source;
		if (!itemCraftConfigs.TryGetValue(value, out var value2))
		{
			source = Enumerable.Empty<ItemConfig>();
		}
		else
		{
			CraftingStation currentCraftingStation = Player.m_localPlayer.GetCurrentCraftingStation();
			if ((object)currentCraftingStation != null)
			{
				string stationName = Utils.GetPrefabName(currentCraftingStation.gameObject);
				source = from c in value2.Where((KeyValuePair<string, ItemConfig> c) =>
					{
						switch (c.Value.table.Value)
						{
						case CraftingTable.Disabled:
						case CraftingTable.Inventory:
							return false;
						case CraftingTable.Custom:
							return c.Value.customTable.Value == stationName;
						default:
							return getInternalName(c.Value.table.Value) == stationName;
						}
					})
					select c.Value;
			}
			else
			{
				source = value2.Values;
			}
		}
		__result = Mathf.Min(Mathf.Max(1, __instance.m_minStationLevel) + (quality - 1), (from cfg in source
			where cfg.maximumTableLevel != null
			select cfg.maximumTableLevel.Value).DefaultIfEmpty(value.MaximumRequiredStationLevel).Max());
	}

	internal static void Patch_GetAvailableRecipesPrefix(ref Dictionary<Assembly, Dictionary<Recipe, ConfigEntryBase>> __state)
	{
		if (__state == null)
		{
			__state = new Dictionary<Assembly, Dictionary<Recipe, ConfigEntryBase>>();
		}
		Dictionary<Recipe, ConfigEntryBase> dictionary;
		if (InventoryGui.instance.InCraftTab())
		{
			dictionary = hiddenCraftRecipes;
		}
		else
		{
			if (!InventoryGui.instance.InUpradeTab())
			{
				return;
			}
			dictionary = hiddenUpgradeRecipes;
		}
		foreach (Recipe key in dictionary.Keys)
		{
			key.m_enabled = false;
		}
		__state[Assembly.GetExecutingAssembly()] = dictionary;
	}

	internal static void Patch_GetAvailableRecipesFinalizer(Dictionary<Assembly, Dictionary<Recipe, ConfigEntryBase>> __state)
	{
		if (!__state.TryGetValue(Assembly.GetExecutingAssembly(), out var value))
		{
			return;
		}
		foreach (KeyValuePair<Recipe, ConfigEntryBase> item in value)
		{
			item.Key.m_enabled = (int)(item.Value?.BoxedValue ?? ((object)1)) != 0;
		}
	}

	internal static IEnumerable<CodeInstruction> Transpile_SetupRequirementList(IEnumerable<CodeInstruction> instructionsEnumerable, ILGenerator ilg)
	{
		List<CodeInstruction> list = instructionsEnumerable.ToList();
		MethodInfo method = AccessTools.DeclaredMethod(typeof(InventoryGui), "SetupRequirement");
		CodeInstruction codeInstruction = null;
		CodeInstruction codeInstruction2 = null;
		LocalBuilder operand = ilg.DeclareLocal(typeof(int));
		Dictionary<Label, int> dictionary = new Dictionary<Label, int>();
		bool flag = false;
		int num = 0;
		int value = 0;
		for (int i = 0; i < list.Count; i++)
		{
			if (list[i].Calls(method))
			{
				codeInstruction = list[i + 2];
				codeInstruction2 = list[i + 5];
				flag = true;
			}
			if (flag)
			{
				if (list[i].Branches(out var label) && dictionary.TryGetValue(label.Value, out value))
				{
					num = i;
					break;
				}
				continue;
			}
			foreach (Label label4 in list[i].labels)
			{
				dictionary[label4] = i;
			}
		}
		if (list[value - 3].opcode == OpCodes.Dup)
		{
			return list;
		}
		Label label2 = ilg.DefineLabel();
		Label label3 = ilg.DefineLabel();
		list[num + 1].labels.Add(label2);
		list.InsertRange(num + 1, new CodeInstruction[11]
		{
			new CodeInstruction(OpCodes.Ldloc, operand),
			new CodeInstruction(OpCodes.Brfalse, label2),
			codeInstruction.Clone(),
			new CodeInstruction(OpCodes.Ldarg_0),
			new CodeInstruction(OpCodes.Ldfld, AccessTools.DeclaredField(typeof(InventoryGui), "m_recipeRequirementList")),
			new CodeInstruction(OpCodes.Ldlen),
			new CodeInstruction(OpCodes.Bgt, label2),
			new CodeInstruction(OpCodes.Ldc_I4_0),
			codeInstruction2.Clone(),
			new CodeInstruction(OpCodes.Ldc_I4_0),
			new CodeInstruction(OpCodes.Br, label3)
		});
		list.InsertRange(value - 2, new CodeInstruction[2]
		{
			new CodeInstruction(OpCodes.Dup)
			{
				labels = new List<Label> { label3 }
			},
			new CodeInstruction(OpCodes.Stloc, operand)
		});
		return list;
	}

	internal static bool Patch_RequirementGetAmount(Piece.Requirement __instance, int qualityLevel, ref int __result)
	{
		if (requirementQuality.TryGetValue(__instance, out var value))
		{
			__result = ((value.quality == qualityLevel) ? __instance.m_amountPerLevel : 0);
			return false;
		}
		return true;
	}

	internal static void Patch_ZNetSceneAwake(ZNetScene __instance)
	{
		foreach (Item registeredItem in registeredItems)
		{
			registeredItem.AssignDropToCreature();
		}
	}

	public void AssignDropToCreature()
	{
		foreach (KeyValuePair<CharacterDrop, CharacterDrop.Drop> characterDrop2 in characterDrops)
		{
			if ((bool)characterDrop2.Key)
			{
				characterDrop2.Key.m_drops.Remove(characterDrop2.Value);
			}
		}
		characterDrops.Clear();
		SerializedDrop serializedDrop = new SerializedDrop(DropsFrom.Drops);
		if (itemDropConfigs.TryGetValue(this, out var value))
		{
			serializedDrop = new SerializedDrop(value.Value);
		}
		foreach (KeyValuePair<Character, CharacterDrop.Drop> item in serializedDrop.toCharacterDrops(ZNetScene.s_instance, Prefab))
		{
			CharacterDrop characterDrop = item.Key.GetComponent<CharacterDrop>();
			if ((object)characterDrop == null)
			{
				characterDrop = item.Key.gameObject.AddComponent<CharacterDrop>();
			}
			characterDrop.m_drops.Add(item.Value);
			characterDrops.Add(characterDrop, item.Value);
		}
	}

	public void UpdateCharacterDrop()
	{
		if ((bool)ZNetScene.instance)
		{
			AssignDropToCreature();
		}
	}

	public void Snapshot(float lightIntensity = 1.3f, Quaternion? cameraRotation = null, Quaternion? itemRotation = null)
	{
		SnapshotItem(Prefab.GetComponent<ItemDrop>(), lightIntensity, cameraRotation, itemRotation);
	}

	public static void SnapshotItem(ItemDrop item, float lightIntensity = 1.3f, Quaternion? cameraRotation = null, Quaternion? itemRotation = null)
	{
		if ((bool)ObjectDB.instance)
		{
			Do();
		}
		else
		{
			plugin.StartCoroutine(Delay());
		}
		IEnumerator Delay()
		{
			yield return null;
			Do();
		}
		void Do()
		{
			Camera component = new GameObject("Camera", typeof(Camera)).GetComponent<Camera>();
			component.backgroundColor = Color.clear;
			component.clearFlags = CameraClearFlags.Color;
			component.fieldOfView = 0.5f;
			component.farClipPlane = 10000000f;
			component.cullingMask = 1073741824;
			component.transform.rotation = cameraRotation ?? Quaternion.Euler(90f, 0f, 45f);
			Light component2 = new GameObject("Light", typeof(Light)).GetComponent<Light>();
			component2.transform.rotation = Quaternion.Euler(150f, 0f, -5f);
			component2.type = LightType.Directional;
			component2.cullingMask = 1073741824;
			component2.intensity = lightIntensity;
			Rect rect = new Rect(0f, 0f, 64f, 64f);
			Transform transform = item.transform.Find("attach");
			GameObject gameObject;
			if ((object)transform != null)
			{
				gameObject = UnityEngine.Object.Instantiate(transform.gameObject);
			}
			else
			{
				ZNetView.m_forceDisableInit = true;
				gameObject = UnityEngine.Object.Instantiate(item.gameObject);
				ZNetView.m_forceDisableInit = false;
			}
			if (itemRotation.HasValue)
			{
				gameObject.transform.rotation = itemRotation.Value;
			}
			Transform[] componentsInChildren = gameObject.GetComponentsInChildren<Transform>();
			for (int i = 0; i < componentsInChildren.Length; i++)
			{
				componentsInChildren[i].gameObject.layer = 30;
			}
			Renderer[] componentsInChildren2 = gameObject.GetComponentsInChildren<Renderer>();
			Vector3 vector = componentsInChildren2.Aggregate(Vector3.positiveInfinity, (Vector3 cur, Renderer renderer) => (!(renderer is ParticleSystemRenderer)) ? Vector3.Min(cur, renderer.bounds.min) : cur);
			Vector3 vector2 = componentsInChildren2.Aggregate(Vector3.negativeInfinity, (Vector3 cur, Renderer renderer) => (!(renderer is ParticleSystemRenderer)) ? Vector3.Max(cur, renderer.bounds.max) : cur);
			Vector3 vector3 = vector2 - vector;
			component.targetTexture = RenderTexture.GetTemporary((int)rect.width, (int)rect.height);
			float num = Mathf.Max(vector3.x, vector3.z);
			float num2 = Mathf.Min(vector3.x, vector3.z);
			float num3 = (num + num2) / Mathf.Sqrt(2f) / Mathf.Tan(component.fieldOfView * ((float)Math.PI / 180f));
			Transform transform2 = component.transform;
			Vector3 vector4 = (vector + vector2) / 2f;
			vector4.y = vector2.y;
			transform2.position = vector4 + new Vector3(0f, num3, 0f);
			component2.transform.position = transform2.position + new Vector3(-2f, 0f, 0.2f) / 3f * (0f - num3);
			component.Render();
			RenderTexture active = RenderTexture.active;
			RenderTexture.active = component.targetTexture;
			Texture2D texture2D = new Texture2D((int)rect.width, (int)rect.height, TextureFormat.RGBA32, mipChain: false);
			texture2D.ReadPixels(rect, 0, 0);
			texture2D.Apply();
			RenderTexture.active = active;
			item.m_itemData.m_shared.m_icons = new Sprite[1] { Sprite.Create(texture2D, rect, new Vector2(0.5f, 0.5f)) };
			UnityEngine.Object.DestroyImmediate(gameObject);
			component.targetTexture.Release();
			UnityEngine.Object.Destroy(component);
			UnityEngine.Object.Destroy(component2);
		}
	}

	private static bool CheckItemIsUpgrade(InventoryGui gui)
	{
		ItemDrop.ItemData itemData = gui.m_selectedRecipe.ItemData;
		if (itemData == null)
		{
			return false;
		}
		return itemData.m_quality > 0;
	}

	internal static IEnumerable<CodeInstruction> Transpile_InventoryGui(IEnumerable<CodeInstruction> instructions)
	{
		List<CodeInstruction> instrs = instructions.ToList();
		FieldInfo amountField = AccessTools.DeclaredField(typeof(Recipe), "m_amount");
		int i = 0;
		while (i < instrs.Count)
		{
			yield return instrs[i];
			if (i > 1 && instrs[i - 2].opcode == OpCodes.Ldfld && instrs[i - 2].OperandIs(amountField) && instrs[i - 1].opcode == OpCodes.Ldc_I4_1 && instrs[i].operand is Label)
			{
				yield return new CodeInstruction(OpCodes.Ldarg_0);
				yield return new CodeInstruction(OpCodes.Call, AccessTools.DeclaredMethod(typeof(Item), "CheckItemIsUpgrade"));
				yield return new CodeInstruction(OpCodes.Brtrue, instrs[i].operand);
			}
			int num = i + 1;
			i = num;
		}
	}

	private static Action<ConfigEntryBase> drawRequirementsConfigTable(Item item, bool isUpgrade)
	{
		return delegate(ConfigEntryBase cfg)
		{
			bool locked = cfg.Description.Tags.Select((object a) => (!(a.GetType().Name == "ConfigurationManagerAttributes")) ? ((bool?)null) : ((bool?)a.GetType().GetField("ReadOnly")?.GetValue(a))).FirstOrDefault((bool? v) => v.HasValue) == true;
			List<Requirement> newReqs = new List<Requirement>();
			bool wasUpdated = false;
			int RightColumnWidth = (int)(configManager?.GetType().GetProperty("RightColumnWidth", BindingFlags.Instance | BindingFlags.NonPublic).GetGetMethod(nonPublic: true)
				.Invoke(configManager, Array.Empty<object>()) ?? ((object)130));
			GUILayout.BeginVertical();
			List<Requirement> reqs = new SerializedRequirements((string)cfg.BoxedValue).Reqs;
			bool flag = false;
			int maxQuality = item.Prefab.GetComponent<ItemDrop>().m_itemData.m_shared.m_maxQuality;
			if (isUpgrade && maxQuality > 2)
			{
				flag = reqs.Any((Requirement r) => r.quality > 0);
				if (flag)
				{
					int count = reqs.Count;
					for (int num = 0; num < count; num++)
					{
						if (reqs[num].quality == 0)
						{
							List<Requirement> list = reqs;
							int index = num;
							Requirement value = reqs[num];
							value.quality = 2;
							list[index] = value;
							for (int num2 = 3; num2 <= maxQuality; num2++)
							{
								List<Requirement> list2 = reqs;
								value = reqs[num];
								value.quality = num2;
								list2.Add(value);
							}
						}
					}
				}
				if (flag != GUILayout.Toggle(flag, "Individual costs per upgrade level"))
				{
					flag = !flag;
					wasUpdated = true;
					if (flag)
					{
						int count2 = reqs.Count;
						for (int num3 = 0; num3 < count2; num3++)
						{
							List<Requirement> list3 = reqs;
							int index2 = num3;
							Requirement value = reqs[num3];
							value.quality = 2;
							list3[index2] = value;
							for (int num4 = 3; num4 <= maxQuality; num4++)
							{
								List<Requirement> list4 = reqs;
								value = reqs[num3];
								value.quality = num4;
								list4.Add(value);
							}
						}
					}
					else
					{
						reqs.RemoveAll((Requirement req) => req.quality > 1);
						for (int num5 = 0; num5 < reqs.Count; num5++)
						{
							List<Requirement> list5 = reqs;
							int index3 = num5;
							Requirement value = reqs[num5];
							value.quality = 0;
							list5[index3] = value;
						}
					}
				}
			}
			if (flag)
			{
				for (int num6 = 2; num6 <= maxQuality; num6++)
				{
					GUILayout.Label($"Upgrade level {num6 - 1}:");
					DisplayQuality(num6);
				}
			}
			else
			{
				DisplayQuality(0);
			}
			GUILayout.EndVertical();
			if (wasUpdated)
			{
				cfg.BoxedValue = new SerializedRequirements(newReqs).ToString();
			}
			void DisplayQuality(int quality)
			{
				foreach (Requirement item2 in reqs.Where((Requirement r) => r.quality == quality))
				{
					GUILayout.BeginHorizontal();
					int num7 = item2.amount;
					if (int.TryParse(GUILayout.TextField(num7.ToString(), new GUIStyle(GUI.skin.textField)
					{
						fixedWidth = 40f
					}), out var result) && result != num7 && !locked)
					{
						num7 = result;
						wasUpdated = true;
					}
					string text = GUILayout.TextField(item2.itemName, new GUIStyle(GUI.skin.textField)
					{
						fixedWidth = RightColumnWidth - 40 - 21 - 21 - 9
					});
					string text2 = (locked ? item2.itemName : text);
					wasUpdated = wasUpdated || text2 != item2.itemName;
					if (GUILayout.Button("x", new GUIStyle(GUI.skin.button)
					{
						fixedWidth = 21f
					}) && !locked)
					{
						wasUpdated = true;
					}
					else
					{
						newReqs.Add(new Requirement
						{
							amount = num7,
							itemName = text2,
							quality = quality
						});
					}
					if (GUILayout.Button("+", new GUIStyle(GUI.skin.button)
					{
						fixedWidth = 21f
					}) && !locked)
					{
						wasUpdated = true;
						newReqs.Add(new Requirement
						{
							amount = 1,
							itemName = "",
							quality = quality
						});
					}
					GUILayout.EndHorizontal();
				}
			}
		};
	}

	private static void drawDropsConfigTable(ConfigEntryBase cfg)
	{
		bool valueOrDefault = cfg.Description.Tags.Select((object a) => (!(a.GetType().Name == "ConfigurationManagerAttributes")) ? ((bool?)null) : ((bool?)a.GetType().GetField("ReadOnly")?.GetValue(a))).FirstOrDefault((bool? v) => v.HasValue) == true;
		List<DropTarget> list = new List<DropTarget>();
		bool flag = false;
		int num = (int)(configManager?.GetType().GetProperty("RightColumnWidth", BindingFlags.Instance | BindingFlags.NonPublic).GetGetMethod(nonPublic: true)
			.Invoke(configManager, Array.Empty<object>()) ?? ((object)130));
		GUILayout.BeginVertical();
		foreach (DropTarget item in new SerializedDrop((string)cfg.BoxedValue).Drops.DefaultIfEmpty(new DropTarget
		{
			min = 1,
			max = 1,
			creature = "",
			chance = 1f
		}))
		{
			GUILayout.BeginHorizontal();
			string text = GUILayout.TextField(item.creature, new GUIStyle(GUI.skin.textField)
			{
				fixedWidth = num - 21 - 21 - 6
			});
			string text2 = (valueOrDefault ? item.creature : text);
			flag = flag || text2 != item.creature;
			bool num2 = GUILayout.Button("x", new GUIStyle(GUI.skin.button)
			{
				fixedWidth = 21f
			});
			bool flag2 = GUILayout.Button("+", new GUIStyle(GUI.skin.button)
			{
				fixedWidth = 21f
			});
			GUILayout.EndHorizontal();
			GUILayout.BeginHorizontal();
			GUILayout.Label("Chance: ");
			float num3 = item.chance;
			if (float.TryParse(GUILayout.TextField((num3 * 100f).ToString(CultureInfo.InvariantCulture), new GUIStyle(GUI.skin.textField)
			{
				fixedWidth = 45f
			}), NumberStyles.Float, CultureInfo.InvariantCulture, out var result) && !Mathf.Approximately(result / 100f, num3) && !valueOrDefault)
			{
				num3 = result / 100f;
				flag = true;
			}
			GUILayout.Label("% Amount: ");
			int num4 = item.min;
			if (int.TryParse(GUILayout.TextField(num4.ToString(), new GUIStyle(GUI.skin.textField)
			{
				fixedWidth = 35f
			}), out var result2) && result2 != num4 && !valueOrDefault)
			{
				num4 = result2;
				flag = true;
			}
			GUILayout.Label(" - ");
			int num5 = item.max;
			if (int.TryParse(GUILayout.TextField(num5.ToString(), new GUIStyle(GUI.skin.textField)
			{
				fixedWidth = 35f
			}), out var result3) && result3 != num5 && !valueOrDefault)
			{
				num5 = result3;
				flag = true;
			}
			GUILayout.EndHorizontal();
			GUILayout.BeginHorizontal();
			bool flag3 = item.levelMultiplier;
			if (GUILayout.Toggle(flag3, "Level scaling drop amount") != flag3)
			{
				flag3 = !flag3;
				flag = true;
			}
			GUILayout.EndHorizontal();
			if (num2 && !valueOrDefault)
			{
				flag = true;
			}
			else
			{
				list.Add(new DropTarget
				{
					creature = text2,
					min = num4,
					max = num5,
					chance = num3,
					levelMultiplier = flag3
				});
			}
			if (flag2 && !valueOrDefault)
			{
				flag = true;
				list.Add(new DropTarget
				{
					min = 1,
					max = 1,
					creature = "",
					chance = 1f,
					levelMultiplier = true
				});
			}
		}
		GUILayout.EndVertical();
		if (flag)
		{
			cfg.BoxedValue = new SerializedDrop(list).ToString();
		}
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
