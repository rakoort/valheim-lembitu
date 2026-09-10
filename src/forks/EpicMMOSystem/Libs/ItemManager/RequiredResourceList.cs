using System.Collections.Generic;
using System.Runtime.CompilerServices;
using BepInEx.Configuration;
using JetBrains.Annotations;

namespace ItemManager;

[PublicAPI]
internal class RequiredResourceList
{
	public readonly List<Requirement> Requirements = new List<Requirement>();

	public bool Free;

	public void Add(string itemName, int amount, int quality = 0)
	{
		Requirements.Add(new Requirement
		{
			itemName = itemName,
			amount = amount,
			quality = quality
		});
	}

	public void Add(string itemName, ConfigEntry<int> amountConfig, int quality = 0)
	{
		Requirements.Add(new Requirement
		{
			itemName = itemName,
			amountConfig = amountConfig,
			quality = quality
		});
	}
}
