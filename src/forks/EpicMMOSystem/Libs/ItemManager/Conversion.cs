using System.Runtime.CompilerServices;
using BepInEx.Configuration;
using JetBrains.Annotations;

namespace ItemManager;

[PublicAPI]
internal class Conversion
{
	internal class ConversionConfig
	{
		public ConfigEntry<string> input;

		public string activePiece;

		public ConfigEntry<ConversionPiece> piece;

		public ConfigEntry<string> customPiece;
	}

	public string Input;

	public ConversionPiece Piece;

	internal string customPiece;

	internal ConversionConfig config;

	public string Custom
	{
		get
		{
			return customPiece;
		}
		set
		{
			customPiece = value;
			Piece = ConversionPiece.Custom;
		}
	}

	public Conversion(Item outputItem)
	{
		outputItem.Conversions.Add(this);
	}
}
