using System.Collections.Generic;
using System.Runtime.CompilerServices;
using JetBrains.Annotations;

namespace ItemManager;

[PublicAPI]
internal class DropTargets
{
	public readonly List<DropTarget> Drops = new List<DropTarget>();

	public void Add(string creatureName, float chance, int min = 1, int? max = null, bool levelMultiplier = true)
	{
		Drops.Add(new DropTarget
		{
			creature = creatureName,
			chance = chance,
			min = min,
			max = (max ?? min),
			levelMultiplier = levelMultiplier
		});
	}
}
