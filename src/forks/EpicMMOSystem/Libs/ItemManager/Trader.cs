using System;
using JetBrains.Annotations;

namespace ItemManager;

[Flags]
[PublicAPI]
internal enum Trader
{
	None = 0,
	Haldor = 1,
	Hildir = 2
}
