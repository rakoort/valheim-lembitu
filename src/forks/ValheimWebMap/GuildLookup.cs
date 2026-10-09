using System;
using System.Reflection;

namespace ValheimWebMap
{
    /// <summary>Optional Northarun/Guilds server store (read from 1.2.3, re-checked at 1.5.1). Called only on the main thread.</summary>
    internal sealed class GuildLookup
    {
        private readonly Action<string> _warn;
        private bool _initialized;
        private bool _disabled;
        private Action _ensureLoaded;
        private MethodInfo _guildOf;
        private FieldInfo _name;
        private readonly object[] _argument = new object[1];

        public GuildLookup(Action<string> warn) { _warn = warn; }

        public string NameOf(long playerId)
        {
            if (_disabled) return null;
            try
            {
                if (!_initialized)
                {
                    _initialized = true;
                    Type server = null;
                    foreach (Assembly assembly in AppDomain.CurrentDomain.GetAssemblies())
                    {
                        server = assembly.GetType("Guilds.GuildServer", false);
                        if (server != null) break;
                    }
                    if (server == null) throw new InvalidOperationException("Northarun/Guilds is absent");
                    MethodInfo ensure = server.GetMethod("EnsureLoaded", BindingFlags.Public | BindingFlags.Static, null, Type.EmptyTypes, null);
                    _guildOf = server.GetMethod("GuildOf", BindingFlags.Public | BindingFlags.Static, null, new[] { typeof(long) }, null);
                    _name = _guildOf?.ReturnType.GetField("Name", BindingFlags.Public | BindingFlags.Instance);
                    if (ensure == null || ensure.ReturnType != typeof(void) || _name == null || _name.FieldType != typeof(string))
                        throw new MissingMemberException("Guilds server lookup API changed");
                    _ensureLoaded = (Action)Delegate.CreateDelegate(typeof(Action), ensure);
                }
                if (playerId == 0) return null;
                _ensureLoaded();
                _argument[0] = playerId;
                object guild = _guildOf.Invoke(null, _argument);
                string name = guild != null ? (string)_name.GetValue(guild) : null;
                return string.IsNullOrEmpty(name) ? null : name;
            }
            catch (Exception error)
            {
                _disabled = true;
                _warn("Web map guild names unavailable: " + (error.InnerException ?? error).Message);
                return null;
            }
        }
    }
}
