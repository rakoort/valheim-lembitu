using System.Runtime.CompilerServices;
using JetBrains.Annotations;

namespace StatusEffectManager;

[PublicAPI]
internal class LocalizeKey
{
	public readonly string Key;

	public LocalizeKey(string key)
	{
		Key = key.Replace("$", "");
	}

	public LocalizeKey English(string key)
	{
		return addForLang("English", key);
	}

	public LocalizeKey Swedish(string key)
	{
		return addForLang("Swedish", key);
	}

	public LocalizeKey French(string key)
	{
		return addForLang("French", key);
	}

	public LocalizeKey Italian(string key)
	{
		return addForLang("Italian", key);
	}

	public LocalizeKey German(string key)
	{
		return addForLang("German", key);
	}

	public LocalizeKey Spanish(string key)
	{
		return addForLang("Spanish", key);
	}

	public LocalizeKey Russian(string key)
	{
		return addForLang("Russian", key);
	}

	public LocalizeKey Romanian(string key)
	{
		return addForLang("Romanian", key);
	}

	public LocalizeKey Bulgarian(string key)
	{
		return addForLang("Bulgarian", key);
	}

	public LocalizeKey Macedonian(string key)
	{
		return addForLang("Macedonian", key);
	}

	public LocalizeKey Finnish(string key)
	{
		return addForLang("Finnish", key);
	}

	public LocalizeKey Danish(string key)
	{
		return addForLang("Danish", key);
	}

	public LocalizeKey Norwegian(string key)
	{
		return addForLang("Norwegian", key);
	}

	public LocalizeKey Icelandic(string key)
	{
		return addForLang("Icelandic", key);
	}

	public LocalizeKey Turkish(string key)
	{
		return addForLang("Turkish", key);
	}

	public LocalizeKey Lithuanian(string key)
	{
		return addForLang("Lithuanian", key);
	}

	public LocalizeKey Czech(string key)
	{
		return addForLang("Czech", key);
	}

	public LocalizeKey Hungarian(string key)
	{
		return addForLang("Hungarian", key);
	}

	public LocalizeKey Slovak(string key)
	{
		return addForLang("Slovak", key);
	}

	public LocalizeKey Polish(string key)
	{
		return addForLang("Polish", key);
	}

	public LocalizeKey Dutch(string key)
	{
		return addForLang("Dutch", key);
	}

	public LocalizeKey Portuguese_European(string key)
	{
		return addForLang("Portuguese_European", key);
	}

	public LocalizeKey Portuguese_Brazilian(string key)
	{
		return addForLang("Portuguese_Brazilian", key);
	}

	public LocalizeKey Chinese(string key)
	{
		return addForLang("Chinese", key);
	}

	public LocalizeKey Japanese(string key)
	{
		return addForLang("Japanese", key);
	}

	public LocalizeKey Korean(string key)
	{
		return addForLang("Korean", key);
	}

	public LocalizeKey Hindi(string key)
	{
		return addForLang("Hindi", key);
	}

	public LocalizeKey Thai(string key)
	{
		return addForLang("Thai", key);
	}

	public LocalizeKey Abenaki(string key)
	{
		return addForLang("Abenaki", key);
	}

	public LocalizeKey Croatian(string key)
	{
		return addForLang("Croatian", key);
	}

	public LocalizeKey Georgian(string key)
	{
		return addForLang("Georgian", key);
	}

	public LocalizeKey Greek(string key)
	{
		return addForLang("Greek", key);
	}

	public LocalizeKey Serbian(string key)
	{
		return addForLang("Serbian", key);
	}

	public LocalizeKey Ukrainian(string key)
	{
		return addForLang("Ukrainian", key);
	}

	private LocalizeKey addForLang(string lang, string value)
	{
		if (Localization.instance.GetSelectedLanguage() == lang)
		{
			Localization.instance.AddWord(Key, value);
		}
		else if (lang == "English" && !Localization.instance.m_translations.ContainsKey(Key))
		{
			Localization.instance.AddWord(Key, value);
		}
		return this;
	}
}
