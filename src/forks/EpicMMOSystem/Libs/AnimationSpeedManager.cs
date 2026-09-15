using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using HarmonyLib;
using JetBrains.Annotations;
using UnityEngine;

internal static class AnimationSpeedManager
{
	public delegate double Handler(Character character, double speed);

	private static readonly Harmony harmony = new Harmony("AnimationSpeedManager");

	private static bool hasMarkerPatch = false;

	private static readonly MethodInfo method = AccessTools.DeclaredMethod(typeof(CharacterAnimEvent), "CustomFixedUpdate");

	private static int index = 0;

	private static bool changed = false;

	private static Handler[][] handlers = Array.Empty<Handler[]>();

	private static readonly Dictionary<int, List<Handler>> handlersPriorities = new Dictionary<int, List<Handler>>();

	[PublicAPI]
	public static void Add(Handler handler, int priority = 400)
	{
		if (!hasMarkerPatch)
		{
			harmony.Patch(method, null, null, null, new HarmonyMethod(AccessTools.DeclaredMethod(typeof(AnimationSpeedManager), "markerPatch")), null);
			hasMarkerPatch = true;
		}
		if (!handlersPriorities.TryGetValue(priority, out List<Handler> value))
		{
			handlersPriorities.Add(priority, value = new List<Handler>());
			harmony.Patch(method, null, new HarmonyMethod(AccessTools.DeclaredMethod(typeof(AnimationSpeedManager), "wrapper")));
		}
		value.Add(handler);
		handlers = (from kv in handlersPriorities
			orderby kv.Key
			select kv.Value.ToArray()).ToArray();
	}

	private static void wrapper(Character ___m_character, Animator ___m_animator)
	{
		double num = (double)___m_animator.speed * 10000000.0 % 100.0;
		if ((!(num > 10.0) || !(num < 30.0)) && !(___m_animator.speed <= 0.001f))
		{
			double num2 = ___m_animator.speed;
			double num3 = handlers[index++].Aggregate(num2, (double current, Handler handler) => handler(___m_character, current));
			if (num3 != num2)
			{
				___m_animator.speed = (float)(num3 - num3 % 1E-05);
				changed = true;
			}
		}
	}

	private static void markerPatch(Animator ___m_animator)
	{
		if (changed)
		{
			double num = (double)___m_animator.speed * 10000000.0 % 100.0;
			if ((num < 10.0 || num > 30.0) ? true : false)
			{
				___m_animator.speed += 1.9E-06f;
			}
			changed = false;
		}
		index = 0;
	}
}
