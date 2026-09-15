using JetBrains.Annotations;

namespace ItemManager;

[PublicAPI]
internal enum ConversionPiece
{
	Disabled,
	[InternalName("smelter")]
	Smelter,
	[InternalName("charcoal_kiln")]
	CharcoalKiln,
	[InternalName("blastfurnace")]
	BlastFurnace,
	[InternalName("windmill")]
	Windmill,
	[InternalName("piece_spinningwheel")]
	SpinningWheel,
	[InternalName("eitrrefinery")]
	EitrRefinery,
	Custom
}
