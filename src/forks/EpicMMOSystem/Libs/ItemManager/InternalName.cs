using System;
using System.Runtime.CompilerServices;

namespace ItemManager;

internal class InternalName : Attribute
{
	public readonly string internalName;

	public InternalName(string internalName)
	{
		this.internalName = internalName;
	}
}
