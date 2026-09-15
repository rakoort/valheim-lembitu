using JetBrains.Annotations;

namespace ItemManager;

[PublicAPI]
internal enum CraftingTable
{
	Disabled,
	Inventory,
	[InternalName("piece_workbench")]
	Workbench,
	[InternalName("piece_cauldron")]
	Cauldron,
	[InternalName("piece_MeadCauldron")]
	MeadCauldron,
	[InternalName("forge")]
	Forge,
	[InternalName("piece_artisanstation")]
	ArtisanTable,
	[InternalName("piece_stonecutter")]
	StoneCutter,
	[InternalName("piece_magetable")]
	MageTable,
	[InternalName("piece_preptable")]
	PrepTable,
	[InternalName("blackforge")]
	BlackForge,
	Custom
}
