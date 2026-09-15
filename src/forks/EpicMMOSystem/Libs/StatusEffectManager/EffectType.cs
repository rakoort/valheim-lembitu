using System.ComponentModel;
using JetBrains.Annotations;

namespace StatusEffectManager;

[PublicAPI]
[Description("The ItemDrop effect to apply the status effect")]
internal enum EffectType
{
	Equip,
	Attack,
	Consume,
	Set
}
