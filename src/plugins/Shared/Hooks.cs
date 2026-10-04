using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using BepInEx.Logging;
using HarmonyLib;

namespace Lembitu;

/// <summary>A member or IL shape a feature relies on is not what it was verified against.</summary>
internal sealed class HookMismatch(string message) : Exception(message);

/// <summary>One Harmony patch a feature applies once every hook it touches is verified.</summary>
internal sealed class PatchPlan(MethodBase original)
{
    public MethodBase Original { get; } = original;
    public HarmonyMethod? Prefix { get; set; }
    public HarmonyMethod? Postfix { get; set; }
    public HarmonyMethod? Transpiler { get; set; }
    public HarmonyMethod? Finalizer { get; set; }

    public IEnumerable<MethodInfo> Patches =>
        new[] { Prefix, Postfix, Transpiler, Finalizer }.Where(p => p != null).Select(p => p!.method);
}

/// <summary>
/// Every hook a feature relies on is looked up by name and signature before anything is patched, the
/// way Oathbound's own VerifyHooks does, because the mods we patch ship often. A feature whose hooks
/// no longer match is switched off on its own and logged; the others keep working. Linked into each
/// plugin as source (src/plugins/Shared), so each assembly carries its own copy.
/// </summary>
internal static class Hooks
{
    public static MethodInfo Method(Type type, string name, Type[] parameters, Type returns)
    {
        MethodInfo method = AccessTools.DeclaredMethod(type, name, parameters)
            ?? throw new HookMismatch($"{type.FullName}.{name}({Describe(parameters)}) not found");
        if (method.ReturnType != returns)
        {
            throw new HookMismatch($"{type.FullName}.{name} returns {method.ReturnType.Name}, expected {returns.Name}");
        }
        return method;
    }

    public static void Field(Type type, string name, Type fieldType)
    {
        FieldInfo field = AccessTools.DeclaredField(type, name)
            ?? throw new HookMismatch($"{type.FullName}.{name} not found");
        if (field.FieldType != fieldType)
        {
            throw new HookMismatch($"{type.FullName}.{name} is {field.FieldType.Name}, expected {fieldType.Name}");
        }
    }

    public static void Property(Type type, string name, Type propertyType, bool setter = false)
    {
        PropertyInfo property = AccessTools.DeclaredProperty(type, name)
            ?? throw new HookMismatch($"{type.FullName}.{name} not found");
        if (property.PropertyType != propertyType || (setter && property.GetSetMethod(true) == null))
        {
            throw new HookMismatch($"{type.FullName}.{name} is not a{(setter ? " settable" : "")} {propertyType.Name}");
        }
    }

    /// <summary>The method's body contains exactly one instruction matching <paramref name="match"/>.</summary>
    public static void Once(MethodBase method, string what, Func<CodeInstruction, bool> match)
    {
        int found = PatchProcessor.GetOriginalInstructions(method).Count(match);
        if (found != 1)
        {
            throw new HookMismatch($"{method.DeclaringType?.Name}.{method.Name}: expected one {what}, found {found}");
        }
    }

    public static HarmonyMethod Patch(Type owner, string name, int priority = -1) =>
        new(AccessTools.DeclaredMethod(owner, name) ?? throw new MissingMethodException(owner.FullName, name))
        {
            priority = priority,
        };

    /// <summary>
    /// Verifies a feature by building its plan, then applies every patch or none. Returns whether the
    /// feature is on.
    /// </summary>
    public static bool Enable(Harmony harmony, ManualLogSource log, string feature, Func<IEnumerable<PatchPlan>> plan)
    {
        List<PatchPlan> plans;
        try
        {
            plans = plan().ToList();
        }
        catch (Exception error)
        {
            log.LogWarning($"{feature}: off, hook not verified: {error.Message}");
            return false;
        }

        var applied = new List<PatchPlan>();
        try
        {
            foreach (PatchPlan p in plans)
            {
                harmony.Patch(p.Original, prefix: p.Prefix, postfix: p.Postfix, transpiler: p.Transpiler, finalizer: p.Finalizer, ilmanipulator: null);
                applied.Add(p);
            }
        }
        catch (Exception error)
        {
            foreach (PatchPlan p in applied)
            {
                foreach (MethodInfo patch in p.Patches)
                {
                    harmony.Unpatch(p.Original, patch);
                }
            }
            log.LogError($"{feature}: off, patching failed: {error}");
            return false;
        }

        log.LogInfo($"{feature}: on");
        return true;
    }

    private static string Describe(Type[] parameters) => string.Join(", ", parameters.Select(p => p.Name));
}
