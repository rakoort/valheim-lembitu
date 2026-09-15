using System;
using System.Reflection;
using UnityEngine;

namespace ItemRequiresSkillLevel
{
    public static class EpicMMOSystem_API
    {
        private static string pluginKey = "EpicMMOSystem";

        private static API_State state = API_State.NotReady;
        private static MethodInfo eGetLevel;
        private static MethodInfo eAddExp;
        private static MethodInfo eGetAttribute;

        private enum API_State
        {
            NotReady, NotInstalled, Ready
        }



        public static int GetLevel()
        {
            int result = 0;
            Init();
            if (eGetLevel != null) result = (int)eGetLevel.Invoke(null, null);
            return result;
        }

        public static int GetAttribute(string attribute)
        {
            if (!Player.m_localPlayer) return 0;
            if (Player.m_localPlayer.m_knownTexts.TryGetValue(pluginKey + "_LevelSystem_" + attribute, out string value))
            {
                if (int.TryParse(value, out int result))
                    return result;
            }
            return 0;
        }

        public static void AddExp(int value)
        {
            Init();
            eAddExp?.Invoke(null, new object[] { value });
        }

        private static void Init()
        {
            if (state is API_State.Ready or API_State.NotInstalled) return;
            if (Type.GetType("EpicMMOSystem.EpicMMOSystem, EpicMMOSystem") == null)
            {
                state = API_State.NotInstalled;
                return;
            }

            Type actionsMO = Type.GetType("API.EMMOS_API, EpicMMOSystem");
            if (actionsMO == null)
            {
                state = API_State.NotInstalled;
                return;
            }

            state = API_State.Ready;

            eGetLevel = actionsMO.GetMethod("GetLevel", BindingFlags.Public | BindingFlags.Static);
            eAddExp = actionsMO.GetMethod("AddExp", BindingFlags.Public | BindingFlags.Static);
            eGetAttribute = actionsMO.GetMethod("GetAttribute", BindingFlags.Public | BindingFlags.Static);
        }
    }
}
