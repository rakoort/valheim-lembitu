using System.ComponentModel;
using System.Runtime.CompilerServices;
using BepInEx.Configuration;

namespace ItemManager;

internal struct Requirement
{
	public string itemName;

	public int amount;

	public ConfigEntry<int> amountConfig;

	[Description("Set to a non-zero value to apply the requirement only for a specific quality")]
	public int quality;
}
