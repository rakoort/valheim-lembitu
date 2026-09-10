using System.Runtime.CompilerServices;
using JetBrains.Annotations;

namespace ItemManager;

[PublicAPI]
internal class Trade
{
	public Trader Trader;

	public uint Price;

	public uint Stack = 1u;

	public string RequiredGlobalKey;
}
