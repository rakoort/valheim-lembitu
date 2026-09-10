using System.Collections.Generic;
using System.Runtime.CompilerServices;
using JetBrains.Annotations;

namespace ItemManager;

[PublicAPI]
internal class CraftingStationList
{
	public readonly List<CraftingStationConfig> Stations = new List<CraftingStationConfig>();

	public void Add(CraftingTable table, int level)
	{
		Stations.Add(new CraftingStationConfig
		{
			Table = table,
			level = level
		});
	}

	public void Add(string customTable, int level)
	{
		Stations.Add(new CraftingStationConfig
		{
			Table = CraftingTable.Custom,
			level = level,
			custom = customTable
		});
	}
}
