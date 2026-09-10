using System.Collections.Generic;
using System.Linq;
using System.Runtime.CompilerServices;
using UnityEngine;

namespace ItemManager;

internal static class LocalizationCache
{
	private static readonly Dictionary<string, Localization> localizations = new Dictionary<string, Localization>();

	internal static void LocalizationPostfix(Localization __instance, string language)
	{
		string key = localizations.FirstOrDefault((KeyValuePair<string, Localization> l) => l.Value == __instance).Key;
		if (key != null)
		{
			localizations.Remove(key);
		}
		if (!localizations.ContainsKey(language))
		{
			localizations.Add(language, __instance);
		}
	}

	public static Localization ForLanguage(string language = null)
	{
		if (localizations.TryGetValue(language ?? PlayerPrefs.GetString("language", "English"), out var value))
		{
			return value;
		}
		value = new Localization();
		if (language != null)
		{
			value.SetupLanguage(language);
		}
		return value;
	}
}
