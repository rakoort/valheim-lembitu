using System;

namespace ItemManager;

[Flags]
internal enum Configurability
{
	Disabled = 0,
	Recipe = 1,
	Stats = 2,
	Drop = 4,
	Trader = 8,
	Full = 0xF
}
