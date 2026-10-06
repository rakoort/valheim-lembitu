using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using BepInEx.Logging;
using HarmonyLib;
using Newtonsoft.Json;
using UnityEngine;

namespace Lembitu.Harness;

// Local, explicitly enabled test seam. All engine work is advanced by the plugin's Update.
internal sealed class HarnessControl
{
    private readonly string directory;
    private readonly bool fixtures;
    private readonly ManualLogSource log;
    private readonly Dictionary<string, UnityEngine.UI.Button> buttons = new();
    private readonly Dictionary<ItemDrop.ItemData, string> itemIds = new();
    private readonly Dictionary<string, GameObject> entities = new();
    private long nextItem;
    private bool ready;
    private float nextPoll;
    private Request? request;
    private IEnumerator? operation;
    private Player? controlledPlayer;
    private PlayerController? controller;
    private bool controllerEnabled;
    private InventoryGui? crafting;
    private string fixtureSpawned = "", fixtureZdo = "";
    private string[]? fixturePrivateKeys;
    private ConsoleState? consoleLines;
    private static Terminal? capturingConsole;
    private static readonly List<string> capturedConsoleLines = new();

    private static void CaptureConsole(Terminal __instance, string text)
    {
        if (__instance == capturingConsole) capturedConsoleLines.Add(text);
    }
    private HarnessKeys.KeyResult? keyResult;
    private readonly List<RecentLine> recentMessages = new();
    private readonly List<RecentLine> chatLines = new();
    private int messageLogIndex, chatBufferIndex;
    private string lastCenter = "", lastTopLeft = "";

    public HarnessControl(string directory, bool fixtures, ManualLogSource log)
    {
        if (!Path.IsPathRooted(directory)) throw new ArgumentException("control directory must be absolute");
        this.directory = directory;
        this.fixtures = fixtures;
        this.log = log;
        Directory.CreateDirectory(Path.Combine(directory, "inbox"));
        Directory.CreateDirectory(Path.Combine(directory, "outbox"));
        Publish("status.json", new Status { ready = false, error = "" });
    }

    public void Ready()
    {
        ready = true;
        Publish("status.json", new Status { ready = true, error = "" });
    }

    public void Fail(string error)
    {
        ready = false;
        try { Publish("status.json", new Status { ready = false, error = error }); }
        catch (Exception failure) { log.LogError(failure); }
    }

    public void Stop()
    {
        if (request != null) Complete("harness stopped during command");
        Fail("harness stopped");
    }

    public void Tick()
    {
        Observe();
        if (ready && (ZNet.instance == null || ZNet.GetConnectionStatus() != ZNet.ConnectionStatus.Connected))
            Fail("connection lost");
        try
        {
            if (operation != null)
            {
                if (!ready && request!.action != "quit") throw new InvalidOperationException("harness is not ready");
                if (!operation.MoveNext()) Complete("");
                return;
            }
            if (Time.realtimeSinceStartup < nextPoll) return;
            nextPoll = Time.realtimeSinceStartup + 0.1f;
            foreach (string path in Directory.EnumerateFiles(Path.Combine(directory, "inbox"), "*.json"))
            {
                string id = Path.GetFileNameWithoutExtension(path);
                if (!Guid.TryParseExact(id, "D", out _)) throw new InvalidDataException("request filename must be a UUID: " + id);
                if (File.Exists(Path.Combine(directory, "outbox", id + ".json")))
                {
                    File.Delete(path); // A retry of an already answered request must not execute twice.
                    continue;
                }
                request = new Request { id = id };
                if (new FileInfo(path).Length > 16384) throw new InvalidDataException("request exceeds 16 KiB");
                Request? parsed = JsonConvert.DeserializeObject<Request>(File.ReadAllText(path));
                if (parsed == null || parsed.id != id) throw new InvalidDataException("request id must match filename");
                request = parsed;
                File.Delete(path);
                fixtureSpawned = "";
                fixtureZdo = "";
                fixturePrivateKeys = null;
                consoleLines = null;
                keyResult = null;
                if (parsed.action != "quit" && !ready) throw new InvalidOperationException("harness is not ready");
                operation = AdvanceNested(Execute(parsed));
                if (!operation.MoveNext()) Complete("");
                break;
            }
        }
        catch (Exception error)
        {
            log.LogError(error);
            if (request != null) Complete(error.ToString());
            else Fail(error.ToString());
        }
    }

    private static IEnumerator AdvanceNested(IEnumerator root)
    {
        var stack = new Stack<IEnumerator>();
        stack.Push(root);
        try
        {
            while (stack.Count > 0)
            {
                IEnumerator current = stack.Peek();
                if (!current.MoveNext())
                {
                    stack.Pop();
                    (current as IDisposable)?.Dispose();
                }
                else if (current.Current is IEnumerator child) stack.Push(child);
                else yield return current.Current;
            }
        }
        finally
        {
            while (stack.Count > 0) (stack.Pop() as IDisposable)?.Dispose();
        }
    }

    /// <summary>
    /// One observation per frame: the HUD message log and the chat buffer carry no times, so new
    /// entries are recorded as they appear. Indexes reset when the game's own caps trim the lists.
    /// Observation must never break the session, so unexpected shapes are skipped.
    /// </summary>
    private void Observe()
    {
        try
        {
            if (MessageHud.instance != null)
            {
                List<string> log = MessageHud.instance.m_messageLog;
                if (messageLogIndex > log.Count) messageLogIndex = 0;
                for (; messageLogIndex < log.Count; messageLogIndex++) Record(recentMessages, "hud", log[messageLogIndex]);
                TrackText(recentMessages, "center", MessageHud.instance.m_messageCenterText != null ? MessageHud.instance.m_messageCenterText.text : "", ref lastCenter);
                TrackText(recentMessages, "topleft", MessageHud.instance.m_messageText != null ? MessageHud.instance.m_messageText.text : "", ref lastTopLeft);
            }
            if (Chat.instance != null)
            {
                List<string> buffer = Chat.instance.m_chatBuffer;
                if (chatBufferIndex > buffer.Count) chatBufferIndex = 0;
                for (; chatBufferIndex < buffer.Count; chatBufferIndex++) Record(chatLines, "chat", buffer[chatBufferIndex]);
            }
        }
        catch (Exception) { /* a broken read is skipped; the next frame retries */ }
    }

    private void TrackText(List<RecentLine> list, string where, string text, ref string last)
    {
        if (text == last) return;
        last = text;
        if (text.Length == 0) return;
        Record(list, where, text);
    }

    private void Record(List<RecentLine> list, string where, string text)
    {
        list.Add(new RecentLine { where = where, text = text, unscaled = Time.unscaledTime, time = DateTime.UtcNow.ToString("o") });
        if (list.Count > 100) list.RemoveRange(0, list.Count - 100);
    }

    private void Complete(string error)
    {
        Request current = request!;
        try
        {
            (operation as IDisposable)?.Dispose();
            ResetControls();
            if (crafting != null && crafting.m_craftTimer >= 0f) crafting.OnCraftCancelPressed();
            crafting = null;
            State? state = null;
            try { if (current.action != "quit") state = Snapshot(); }
            catch (Exception failure) { error += "\nSnapshot failed: " + failure; }
            Publish(Path.Combine("outbox", current.id + ".json"), new Response
            {
                id = current.id, ok = error.Length == 0, error = error, state = state
            });
            if (current.action == "quit" && error.Length == 0) Application.Quit();
        }
        catch (Exception failure) { log.LogError(failure); Fail(failure.ToString()); }
        finally { request = null; operation = null; }
    }

    private IEnumerator Execute(Request command)
    {
        Player player = Player.m_localPlayer;
        if (command.action == "snapshot" || command.action == "quit") yield break;
        if (player == null) throw new InvalidOperationException("waiting for local player to respawn");
        if (player.IsDead() || player.IsTeleporting() || player.InCutscene())
            throw new InvalidOperationException("player is dead, teleporting, or in a cutscene");
        switch (command.action)
        {
            case "move":
            {
                Duration(command.seconds);
                if (!Finite(command.x) || !Finite(command.z) || Mathf.Abs(command.x) > 1 || Mathf.Abs(command.z) > 1)
                    throw new ArgumentException("move x/z must be finite directions in [-1,1]");
                Vector3 direction = Vector3.ClampMagnitude(new Vector3(command.x, 0, command.z), 1);
                TakeControls(player);
                float end = Time.realtimeSinceStartup + command.seconds;
                while (Time.realtimeSinceStartup < end)
                {
                    CheckPlayer(player);
                    if (direction != Vector3.zero) player.SetLookDir(direction.normalized);
                    Controls(player, Vector3.forward * direction.magnitude);
                    yield return null;
                }
                break;
            }
            case "attack":
            {
                Duration(command.seconds);
                GameObject target = Target(command.target);
                if (target == player.gameObject) throw new ArgumentException("cannot attack self");
                TakeControls(player);
                float end = Time.realtimeSinceStartup + command.seconds;
                bool started = false;
                while (Time.realtimeSinceStartup < end)
                {
                    CheckPlayer(player);
                    if (target == null) break;
                    Character victim = target.GetComponent<Character>();
                    if (victim != null && victim.IsDead()) break;
                    Vector3 direction = target.transform.position - player.transform.position;
                    direction.y = 0;
                    if (direction.sqrMagnitude > 0.001f) player.SetLookDir(direction.normalized);
                    Controls(player, Vector3.zero);
                    if (!player.InAttack()) started |= player.StartAttack(victim, command.secondary);
                    yield return null;
                }
                if (!started) throw new InvalidOperationException("engine rejected every attack attempt");
                // Do not acknowledge an animation still waiting to deliver its hit.
                float settle = Time.realtimeSinceStartup + 10f;
                while (player.InAttack())
                {
                    CheckPlayer(player);
                    if (Time.realtimeSinceStartup >= settle) throw new TimeoutException("attack did not finish");
                    yield return null;
                }
                break;
            }
            case "equip":
            {
                ItemDrop.ItemData? item = player.GetInventory().GetAllItems().Find(i => ItemId(i) == command.item);
                if (item == null) throw new ArgumentException("inventory item ID not found");
                if (!player.EquipItem(item)) throw new InvalidOperationException("engine rejected equip");
                yield return null;
                break;
            }
            case "use":
            {
                // Two paths, both vanilla. Without a target: the inventory's right-click (consume,
                // drink). With an observed target: item-on-object, the path seed beds and similar
                // Interactable.UseItem hooks take. Mod refusals surface as HUD messages and an
                // unchanged inventory, which the scenario asserts on; neither call reports a result.
                ItemDrop.ItemData? used = player.GetInventory().GetAllItems().Find(i => ItemId(i) == command.item);
                if (used == null) throw new ArgumentException("inventory item ID not found");
                if (command.target.Length > 0)
                {
                    GameObject hover = Part(Target(command.target), command.text);
                    if (hover.GetComponentInParent<Hoverable>() == null)
                        throw new ArgumentException("use target is not hoverable");
                    if (Vector3.Distance(player.transform.position, hover.transform.position) > player.m_maxInteractDistance)
                        throw new InvalidOperationException("target outside interaction range");
                    player.TryUseItemOnInteractable(used, hover, fromInventoryGui: false);
                }
                else
                {
                    player.UseItem(player.GetInventory(), used, fromInventoryGui: true);
                }
                yield return null;
                yield return null;
                break;
            }
            case "craft":
            {
                InventoryGui gui = InventoryGui.instance ?? throw new InvalidOperationException("inventory UI unavailable");
                if (gui.m_craftTimer >= 0) throw new InvalidOperationException("craft already in progress");
                crafting = gui;
                crafting.Show(null);
                crafting.OnTabCraftPressed();
                int index = crafting.m_availableRecipes.FindIndex(r => r.Recipe.name == command.recipe);
                if (index < 0) throw new ArgumentException("recipe unavailable: " + command.recipe);
                crafting.SetRecipe(index, false);
                crafting.UpdateRecipe(player, 0);
                if (!crafting.m_craftButton.IsInteractable()) throw new InvalidOperationException("craft button disabled: requirements not met");
                crafting.OnCraftPressed();
                if (crafting.m_craftTimer < 0) throw new InvalidOperationException("engine rejected crafting");
                float end = Time.realtimeSinceStartup + 30f;
                while (crafting.m_craftTimer >= 0)
                {
                    CheckPlayer(player);
                    if (Time.realtimeSinceStartup >= end) throw new TimeoutException("crafting did not finish");
                    yield return null;
                }
                crafting = null;
                break;
            }
            case "interact":
            {
                GameObject target = Part(Target(command.target), command.text);
                if (target.GetComponentInParent<Interactable>() == null) throw new ArgumentException("target is not interactable");
                if (Vector3.Distance(player.transform.position, target.transform.position) > player.m_maxInteractDistance)
                    throw new InvalidOperationException("target outside interaction range");
                if (player.InAttack() || player.InDodge()) throw new InvalidOperationException("player cannot interact during attack/dodge");
                player.Interact(target, false, command.secondary);
                // Pickup ownership requests are asynchronous in vanilla. Await that path, not a guessed delay.
                ItemDrop drop = target.GetComponent<ItemDrop>();
                float end = Time.realtimeSinceStartup + 10f;
                while (drop != null && drop.IsInvoking("PickupUpdate"))
                {
                    if (Time.realtimeSinceStartup >= end) throw new TimeoutException("pickup ownership did not settle");
                    yield return null;
                }
                yield return null;
                break;
            }
            case "pvp":
                player.SetPVP(command.value);
                yield return null;
                break;
            case "ui":
                if (command.target == "inventory")
                {
                    if (command.value) InventoryGui.instance.Show(null); else InventoryGui.instance.Hide();
                }
                else if (command.target == "map") Minimap.instance.SetMapMode(command.value ? Minimap.MapMode.Large : Minimap.MapMode.Small);
                else
                {
                    if (!command.value || !buttons.TryGetValue(command.target, out UnityEngine.UI.Button button) || button == null)
                        throw new ArgumentException("ui target must be inventory, map, or an observed button ID with value=true");
                    if (!button.gameObject.activeInHierarchy || !button.IsInteractable())
                        throw new InvalidOperationException("UI button is inactive or disabled");
                    button.onClick.Invoke();
                }
                // IsVisible uses frame counters; allow the actual UI to advance.
                yield return null;
                yield return null;
                yield return null;
                break;
            case "screenshot":
            {
                if (!Path.IsPathRooted(command.target) || File.Exists(command.target))
                    throw new ArgumentException("screenshot target must be a new absolute file path");
                ScreenCapture.CaptureScreenshot(command.target);
                float end = Time.realtimeSinceStartup + 15f;
                while (!File.Exists(command.target) || new FileInfo(command.target).Length == 0)
                {
                    if (Time.realtimeSinceStartup >= end) throw new TimeoutException("screenshot was not written");
                    yield return null;
                }
                break;
            }
            case "fixture.spawn":
            {
                if (!fixtures) throw new InvalidOperationException("fixture actions require -lembitu-fixtures; never gameplay proof");
                Vector3 position = new(command.x, command.y, command.z);
                if (!Finite(command.x) || !Finite(command.y) || !Finite(command.z) || Vector3.Distance(position, player.transform.position) > 20)
                    throw new ArgumentException("fixture position must be finite and within 20m of player");
                GameObject prefab = ZNetScene.instance.GetPrefab(command.target);
                if (prefab == null || prefab.GetComponent<ZNetView>() == null) throw new ArgumentException("network prefab not found");
                GameObject spawned = UnityEngine.Object.Instantiate(prefab, position, Quaternion.Euler(0f, command.yaw, 0f));
                fixtureSpawned = spawned.GetInstanceID().ToString();
                yield return null;
                break;
            }
            case "fixture.privatekeys":
            {
                RequireFixtures();
                Type type = Type.GetType("VentureValheim.Progression.KeyManager, VentureValheim.Progression", throwOnError: false)
                    ?? throw new InvalidOperationException("WAP KeyManager is unavailable");
                object manager = AccessTools.Property(type, "Instance")?.GetValue(null)
                    ?? throw new InvalidOperationException("WAP KeyManager.Instance is unavailable");
                var reset = AccessTools.Method(type, "ResetPrivateKeys", Type.EmptyTypes)
                    ?? throw new MissingMethodException(type.FullName, "ResetPrivateKeys()");
                var add = AccessTools.Method(type, "AddPrivateKey", new[] { typeof(string) })
                    ?? throw new MissingMethodException(type.FullName, "AddPrivateKey(string)");
                var keys = AccessTools.Property(type, "PrivateKeysList")
                    ?? throw new MissingMemberException(type.FullName, "PrivateKeysList");
                // Use WAP's own mutations so its live list, server state and skill config agree.
                reset.Invoke(manager, Array.Empty<object>());
                object[] argument = new object[1];
                foreach (string key in command.text.Split(new[] { ',' }, StringSplitOptions.RemoveEmptyEntries))
                {
                    argument[0] = key.Trim();
                    add.Invoke(manager, argument);
                }
                fixturePrivateKeys = ((HashSet<string>)keys.GetValue(manager)).ToArray();
                yield return null;
                break;
            }
            case "fixture.freeze":
            {
                RequireFixtures();
                Character npc = Target(command.target).GetComponent<Character>() ?? throw new ArgumentException("freeze target is not a character");
                if (npc is Player) throw new ArgumentException("freeze target must be an NPC");
                BaseAI ai = npc.GetBaseAI() ?? throw new ArgumentException("freeze target has no AI");
                ZNetView view = npc.GetComponent<ZNetView>();
                if (view == null || !view.IsValid() || !view.IsOwner())
                    throw new InvalidOperationException("freeze target must be locally owned");
                Rigidbody body = npc.GetComponent<Rigidbody>() ?? throw new ArgumentException("freeze target has no rigidbody");
                // Keep the enemy lookup registry intact, so companion AI can still target it.
                BaseAI.Instances.Remove(ai);
                npc.SetMoveDir(Vector3.zero);
                body.linearVelocity = Vector3.zero;
                body.angularVelocity = Vector3.zero;
                body.constraints = RigidbodyConstraints.FreezeAll;
                npc.m_regenAllHPTime = float.MaxValue;
                yield return null;
                break;
            }
            case "fixture.hit":
            {
                // The player's hit, sent the way a weapon's is: vanilla Character.Damage RPCs it to the
                // target's owner, whose RPC_Damage applies it and starts any poison there.
                RequireFixtures();
                Character victim = Target(command.target).GetComponent<Character>() ?? throw new ArgumentException("hit target is not a character");
                if (victim is Player) throw new ArgumentException("hit target must be an NPC");
                if (!Finite(command.x) || !Finite(command.y) || command.x < 0 || command.y < 0 || command.x + command.y <= 0)
                    throw new ArgumentException("hit needs non-negative poison (x) and blunt (y) damage, not both zero");
                var hit = new HitData { m_point = victim.GetCenterPoint(), m_dir = (victim.transform.position - player.transform.position).normalized };
                hit.m_damage.m_poison = command.x;
                hit.m_damage.m_blunt = command.y;
                hit.SetAttacker(player);
                victim.Damage(hit);
                yield return null;
                break;
            }
            case "fixture.chop":
            {
                // The player's chop on a fallen log, sent through TreeLog.Damage as an axe's hit is.
                RequireFixtures();
                TreeLog log = Target(command.target).GetComponent<TreeLog>() ?? throw new ArgumentException("chop target is not a fallen log");
                if (!Finite(command.x) || command.x <= 0 || !Finite(command.y) || command.y < 0)
                    throw new ArgumentException("chop needs positive damage (x) and a non-negative tool tier (y)");
                var hit = new HitData { m_point = log.transform.position, m_dir = (log.transform.position - player.transform.position).normalized,
                    m_toolTier = (short)Mathf.Min(command.y, 100f) };
                hit.m_damage.m_chop = command.x;
                hit.SetAttacker(player);
                log.Damage(hit);
                yield return null;
                break;
            }
            case "fixture.cast":
            {
                // A float cast by the equipped rod with its bait, set up the way Attack sets up a
                // projectile. The float prefab is the bait's or rod's projectile when it carries a
                // FishingFloat, otherwise the registered prefab that does.
                RequireFixtures();
                ItemDrop.ItemData rod = player.GetCurrentWeapon() ?? throw new InvalidOperationException("equip a fishing rod first");
                ItemDrop.ItemData bait = player.GetInventory().GetAllItems().Find(i => i != rod && i.m_shared.m_ammoType.Length > 0 && i.m_shared.m_ammoType == rod.m_shared.m_ammoType)
                    ?? throw new InvalidOperationException("no bait for the equipped item");
                GameObject? projectile = new[] { bait.m_shared.m_attack.m_attackProjectile, rod.m_shared.m_attack.m_attackProjectile }
                    .FirstOrDefault(p => p != null && p.GetComponentInChildren<FishingFloat>(true) != null);
                if (projectile == null) projectile = ZNetScene.instance.m_prefabs.Find(p => p != null && p.GetComponent<FishingFloat>() != null);
                if (projectile == null) throw new InvalidOperationException("no fishing float prefab is registered");
                Vector3 forward = player.transform.forward;
                GameObject cast = UnityEngine.Object.Instantiate(projectile, player.transform.position + Vector3.up * 1.5f + forward, Quaternion.LookRotation(forward));
                FishingFloat castFloat = cast.GetComponentInChildren<FishingFloat>(true);
                castFloat.Setup(player, forward * 12f + Vector3.up * 4f, -1f, new HitData(), rod, bait);
                fixtureSpawned = castFloat.gameObject.GetInstanceID().ToString();
                yield return null;
                break;
            }
            case "fixture.raise":
            {
                // One skill gain through Character.RaiseSkill, the path every activity's XP takes.
                RequireFixtures();
                if (!Finite(command.x) || command.x <= 0) throw new ArgumentException("raise needs a positive factor (x)");
                player.RaiseSkill(SkillType(command.target), command.x);
                yield return null;
                break;
            }
            case "fixture.zdo":
            {
                RequireFixtures();
                ZNetView view = Target(command.target).GetComponent<ZNetView>() ?? throw new ArgumentException("target has no network view");
                if (!view.IsValid() || command.text.Length == 0) throw new ArgumentException("zdo needs a valid target and a key (text)");
                ZDO zdo = view.GetZDO();
                fixtureZdo = $"bool={zdo.GetBool(command.text)} int={zdo.GetInt(command.text)} float={zdo.GetFloat(command.text)} string={zdo.GetString(command.text)}";
                yield return null;
                break;
            }
            case "fixture.skill":
            {
                RequireFixtures();
                Skills.SkillType type = SkillType(command.target);
                if (!Finite(command.x) || !Finite(command.y) || command.x < 0 || command.x > 100 || command.y < 0)
                    throw new ArgumentException("skill level must be in [0,100] and accumulator non-negative");
                Skills.Skill skill = player.GetSkills().GetSkill(type);
                if (skill.m_info == null) throw new ArgumentException("skill has no definition: " + command.target);
                skill.m_level = command.x;
                skill.m_accumulator = command.y;
                yield return null;
                break;
            }
            case "fixture.give":
            {
                RequireFixtures();
                GameObject prefab = ObjectDB.instance.GetItemPrefab(command.target);
                int amount = (int)command.x;
                if (prefab == null || amount < 1 || amount > 999) throw new ArgumentException("item prefab not found or amount outside [1,999]");
                // Optional quality (y) and custom data (text, "key=value;key=value"), for items the
                // game only makes elsewhere, such as a graded dish to put into a cooking station.
                int quality = command.y >= 1 ? (int)command.y : 1;
                for (int given = 0; given < amount;)
                {
                    int stack = Mathf.Min(amount - given, prefab.GetComponent<ItemDrop>().m_itemData.m_shared.m_maxStackSize);
                    bool added;
                    if (quality == 1 && command.text.Length == 0)
                    {
                        added = player.GetInventory().AddItem(prefab, stack);
                    }
                    else
                    {
                        ItemDrop.ItemData item = prefab.GetComponent<ItemDrop>().m_itemData.Clone();
                        item.m_dropPrefab = prefab;
                        item.m_stack = stack;
                        item.m_quality = quality;
                        item.m_customData = new Dictionary<string, string>();
                        foreach (string pair in command.text.Split(new[] { ';' }, StringSplitOptions.RemoveEmptyEntries))
                        {
                            string[] kv = pair.Split(new[] { '=' }, 2);
                            if (kv.Length != 2) throw new ArgumentException("custom data must be key=value pairs separated by ';'");
                            item.m_customData[kv[0]] = kv[1];
                        }
                        added = player.GetInventory().AddItem(item);
                    }
                    if (!added) throw new InvalidOperationException("inventory full");
                    given += stack;
                }
                yield return null;
                break;
            }
            case "fixture.teleport":
            {
                RequireFixtures();
                Vector3 target = new(command.x, command.y, command.z);
                if (!Finite(command.x) || !Finite(command.y) || !Finite(command.z)) throw new ArgumentException("teleport position must be finite");
                if (command.target.StartsWith("location:", StringComparison.Ordinal))
                {
                    string location = command.target.Substring("location:".Length);
                    var icons = new Dictionary<Vector3, string>();
                    ZoneSystem.instance.GetLocationIcons(icons);
                    KeyValuePair<Vector3, string> icon = icons.FirstOrDefault(i => i.Value == location);
                    if (icon.Value != location) throw new ArgumentException("no location icon named " + location);
                    target += icon.Key;
                }
                else if (command.target.Length > 0) throw new ArgumentException("teleport target must be empty or location:<name>");
                if (!player.TeleportTo(target, player.transform.rotation, distantTeleport: true)) throw new InvalidOperationException("engine refused teleport");
                float end = Time.realtimeSinceStartup + 60f;
                while (player.IsTeleporting())
                {
                    if (Time.realtimeSinceStartup >= end) throw new TimeoutException("teleport did not finish");
                    yield return null;
                }
                break;
            }
            case "fixture.catch":
            {
                // The reel-in is skipped; landing itself is vanilla's FishingFloat.Catch.
                RequireFixtures();
                Fish fish = Target(command.target).GetComponent<Fish>() ?? throw new ArgumentException("target is not a fish");
                FishingFloat.Catch(fish, player);
                yield return null;
                yield return null;
                break;
            }
            case "fixture.die":
            {
                RequireFixtures();
                var hit = new HitData { m_point = player.transform.position };
                hit.m_damage.m_damage = 1e6f;
                player.Damage(hit);
                float end = Time.realtimeSinceStartup + 10f;
                while (!player.IsDead())
                {
                    if (Time.realtimeSinceStartup >= end) throw new TimeoutException("lethal damage did not kill the player");
                    yield return null;
                }
                break;
            }
            case "fixture.console":
            {
                RequireFixtures();
                Console console = Console.instance ?? throw new InvalidOperationException("console unavailable");
                if (command.target.Length == 0) throw new ArgumentException("console command line must not be empty");
                var harmony = new Harmony("lembitu.harness.console-capture");
                var addString = AccessTools.Method(typeof(Terminal), "AddString", new[] { typeof(string) });
                var capture = AccessTools.Method(typeof(HarnessControl), nameof(CaptureConsole));
                capturedConsoleLines.Clear();
                capturingConsole = console;
                harmony.Patch(addString, prefix: new HarmonyMethod(capture));
                try
                {
                    int before = 0;
                    console.TryRunCommand(command.target);
                    float deadline = Time.realtimeSinceStartup + 8f, lastNew = Time.realtimeSinceStartup;
                    while (Time.realtimeSinceStartup < deadline)
                    {
                        CheckPlayer(player);
                        int count = capturedConsoleLines.Count;
                        if (count != before) { before = count; lastNew = Time.realtimeSinceStartup; }
                        else if (Time.realtimeSinceStartup - lastNew >= 0.75f) break;
                        yield return null;
                    }
                    consoleLines = new ConsoleState { command = command.target, lines = capturedConsoleLines.ToArray() };
                    log.LogInfo($"console '{command.target}' -> {capturedConsoleLines.Count} line(s)");
                }
                finally
                {
                    capturingConsole = null;
                    harmony.Unpatch(addString, capture);
                    capturedConsoleLines.Clear();
                }
                break;
            }
            case "fixture.customdata":
            {
                RequireFixtures();
                if (command.target.Length == 0) throw new ArgumentException("customdata key must not be empty");
                if (command.value) player.m_customData[command.target] = command.text;
                else player.m_customData.Remove(command.target);
                yield return null;
                break;
            }
            case "key":
            {
                if (command.seconds > 0) Duration(command.seconds);
                keyResult = null;
                yield return HarnessKeys.Press(command.target, command.method,
                    command.seconds > 0 ? command.seconds : 0.15f, log, result => keyResult = result);
                if (keyResult == null) throw new InvalidOperationException("key press produced no result");
                log.LogInfo($"key {keyResult.key} via {keyResult.method}: pressed={keyResult.pressed}");
                break;
            }
            case "text":
            {
                // Real OS typing into the focused input field; there is no synthetic fallback
                // because a string is a layout question, not a key-state one.
                keyResult = null;
                yield return HarnessKeys.Type(command.target, log, result => keyResult = result);
                log.LogInfo($"typed {command.target.Length} chars via {keyResult?.method}");
                break;
            }
            default: throw new ArgumentException("unknown action: " + command.action);
        }
    }

    private static void Duration(float seconds)
    {
        if (!Finite(seconds) || seconds <= 0 || seconds > 10) throw new ArgumentException("seconds must be in (0,10]");
    }
    private static bool Finite(float value) => !float.IsNaN(value) && !float.IsInfinity(value);
    private void RequireFixtures()
    {
        if (!fixtures) throw new InvalidOperationException("fixture actions require -lembitu-fixtures; never gameplay proof");
    }
    /// <summary>A vanilla skill by enum name, or "hash:Name" for a Jotunn or bundled-manager skill.</summary>
    private static Skills.SkillType SkillType(string reference) =>
        reference.StartsWith("hash:", StringComparison.Ordinal)
            ? (Skills.SkillType)Math.Abs(reference.Substring("hash:".Length).GetStableHashCode())
            : (Skills.SkillType)Enum.Parse(typeof(Skills.SkillType), reference);
    private static void CheckPlayer(Player player)
    {
        if (player == null || player != Player.m_localPlayer || player.IsDead() || player.IsTeleporting())
            throw new InvalidOperationException("controlled player disappeared, died, or teleported");
    }
    private void TakeControls(Player player)
    {
        controlledPlayer = player;
        controller = player.GetComponent<PlayerController>();
        if (controller == null) throw new InvalidOperationException("player input controller absent");
        controllerEnabled = controller.enabled;
        controller.enabled = false;
        // Cancel existing autorun through the same nonzero directional input as the game.
        Controls(player, Vector3.forward);
        Controls(player, Vector3.zero);
    }
    private static void Controls(Player player, Vector3 direction) => player.SetControls(direction,
        false, false, false, false, false, false, false, false, false, false);
    private void ResetControls()
    {
        try { if (controlledPlayer != null) Controls(controlledPlayer, Vector3.zero); }
        finally
        {
            if (controller != null) controller.enabled = controllerEnabled;
            controller = null;
            controlledPlayer = null;
        }
    }
    private GameObject Target(string id)
    {
        if (!entities.TryGetValue(id, out GameObject target) || target == null)
            throw new ArgumentException("entity ID unavailable; take a fresh snapshot");
        return target;
    }
    /// <summary>
    /// A part of a target that takes the interaction instead of its root: "station.food" and
    /// "station.fuel" are a cooking station's add-food and add-fuel switches (an oven's), any other
    /// name is a child by name. Empty names the target itself.
    /// </summary>
    private static GameObject Part(GameObject target, string part)
    {
        if (part.Length == 0) return target;
        CookingStation? station = target.GetComponent<CookingStation>();
        if (station != null && part == "station.food" && station.m_addFoodSwitch != null) return station.m_addFoodSwitch.gameObject;
        if (station != null && part == "station.fuel" && station.m_addFuelSwitch != null) return station.m_addFuelSwitch.gameObject;
        foreach (Transform child in target.GetComponentsInChildren<Transform>(true))
        {
            if (child.name == part) return child.gameObject;
        }
        throw new ArgumentException($"target has no part named {part}");
    }
    private string ItemId(ItemDrop.ItemData item)
    {
        if (!itemIds.TryGetValue(item, out string id)) itemIds.Add(item, id = (++nextItem).ToString());
        return id;
    }

    private static readonly HashSet<string> VanillaPanels = new()
    {
        "hud", "inventorygui", "minimap", "chat", "console", "storegui", "textinput", "menu",
        "settings", "fejdstartup", "player", "loading", "tutorial", "keyhints", "deathscreen",
        "versionlabel", "socialpanel", "passwordpanel", "connectionfailedpanel", "fade"
    };

    private State Snapshot()
    {
        Player player = Player.m_localPlayer;
        if (player == null) throw new InvalidOperationException("no local player");
        Vector3 position = player.transform.position;
        List<EntityState> nearby = new();
        entities.Clear();
        foreach (ZNetView view in UnityEngine.Object.FindObjectsByType<ZNetView>(FindObjectsSortMode.None))
        {
            if (!view.IsValid() || Vector3.SqrMagnitude(view.transform.position - position) > 2500) continue;
            GameObject go = view.gameObject;
            string id = go.GetInstanceID().ToString();
            if (entities.ContainsKey(id)) continue;
            entities.Add(id, go);
            Character character = go.GetComponent<Character>();
            Vector3 p = go.transform.position;
            nearby.Add(new EntityState { id = id, prefab = Utils.GetPrefabName(go), name = character != null ? character.GetHoverName() : go.name,
                x = p.x, y = p.y, z = p.z, health = character != null ? character.GetHealth() : -1,
                maxHealth = character != null ? character.GetMaxHealth() : -1,
                isPlayer = character is Player, interactable = go.GetComponentInParent<Interactable>() != null });
        }
        buttons.Clear();
        List<ButtonState> buttonStates = new();
        foreach (UnityEngine.UI.Button button in UnityEngine.Object.FindObjectsByType<UnityEngine.UI.Button>(FindObjectsInactive.Include, FindObjectsSortMode.None))
        {
            string id = button.GetInstanceID().ToString();
            buttons.Add(id, button);
            TMPro.TMP_Text label = button.GetComponentInChildren<TMPro.TMP_Text>(true);
            buttonStates.Add(new ButtonState { id = id, text = label != null ? label.text : button.name,
                active = button.gameObject.activeInHierarchy, interactable = button.IsInteractable() });
        }
        InventoryGui gui = InventoryGui.instance;
        return new State
        {
            player = new PlayerState { id = player.gameObject.GetInstanceID().ToString(), name = player.GetPlayerName(), x = position.x, y = position.y, z = position.z,
                health = player.GetHealth(), dead = player.IsDead(), pvp = player.IsPVPEnabled(),
                swimming = player.IsSwimming(), stamina = player.GetStamina(),
                eitr = player.GetEitr(), maxEitr = player.GetMaxEitr(),
                maxHealth = player.GetMaxHealth(), maxStamina = player.GetMaxStamina(),
                weight = player.GetInventory().GetTotalWeight(), maxCarry = player.GetMaxCarryWeight(),
                waterLevel = player.GetLiquidLevel(), biome = player.GetCurrentBiome().ToString(),
                terrainHeight = WorldGenerator.instance.GetHeight(position) },
            inventory = player.GetInventory().GetAllItems().Select(i => new ItemState { id = ItemId(i), prefab = i.m_dropPrefab != null ? i.m_dropPrefab.name : "",
                name = i.m_shared.m_name, stack = i.m_stack, quality = i.m_quality, equipped = i.m_equipped, x = i.m_gridPos.x, y = i.m_gridPos.y,
                customData = i.m_customData.Select(k => new TextState { key = k.Key, value = k.Value }).ToArray(), tooltip = i.GetTooltip() }).ToArray(),
            foods = player.GetFoods().Select(f => new FoodState { name = f.m_name, time = f.m_time, health = f.m_health, stamina = f.m_stamina, eitr = f.m_eitr }).ToArray(),
            statusEffects = player.GetSEMan().GetStatusEffects().Select(s => new EffectState { name = s.name, label = s.m_name, remaining = s.GetRemaningTime() }).ToArray(),
            entities = nearby.ToArray(),
            progression = player.m_knownTexts.Select(k => new TextState { key = k.Key, value = k.Value }).ToArray(),
            customData = player.m_customData.Select(k => new TextState { key = k.Key, value = k.Value }).ToArray(),
            skills = player.GetSkills().m_skillData.Values.Where(s => s.m_info != null).Select(s => new SkillState
                { type = (int)s.m_info.m_skill, name = s.m_info.m_skill.ToString(), level = s.m_level, accumulator = s.m_accumulator,
                  effective = player.GetSkills().GetSkillLevel(s.m_info.m_skill) }).ToArray(),
            messages = MessageHud.instance == null ? new MessageState() : new MessageState
                { center = MessageHud.instance.m_messageCenterText.text, topLeft = MessageHud.instance.m_messageText.text },
            recentMessages = recentMessages.ToArray(),
            chat = chatLines.ToArray(),
            windows = Windows().ToArray(),
            mapPins = Minimap.instance == null ? Array.Empty<MapPinState>() : Minimap.instance.m_pins.Select(p =>
                new MapPinState { name = p.m_name, save = p.m_save, type = p.m_type.ToString(), x = p.m_pos.x, y = p.m_pos.y, z = p.m_pos.z }).ToArray(),
            explorerTrackers = ExplorerTrackers(),
            ui = new UiState { inventory = InventoryGui.IsVisible(), map = Minimap.IsOpen(), crafting = gui != null && gui.m_craftTimer >= 0,
                buttons = buttonStates.ToArray(), craftEnabled = gui != null && gui.m_craftButton.IsInteractable(),
                recipes = gui == null ? Array.Empty<string>() : gui.m_availableRecipes.Select(r => r.Recipe.name).ToArray() },
            admin = ObservedAdmin(),
            adminList = ZNet.instance == null ? Array.Empty<string>() : ZNet.instance.GetAdminList().ToArray(),
            localUserId = UserInfo.GetLocalUser().UserId.ToString(),
            platformUserId = PlatformUserId(),
            steamId = SteamId(),
            console = consoleLines,
            keyPress = keyResult,
            connection = ZNet.instance == null ? "absent" : ZNet.GetConnectionStatus().ToString(),
            fixtureSpawned = fixtureSpawned,
            fixtureZdo = fixtureZdo,
            fixturePrivateKeys = fixturePrivateKeys
        };
    }

    private static ExplorerTrackerState[] ExplorerTrackers()
    {
        try
        {
            Type? type = AccessTools.TypeByName("Explorer.Patches.Tracker");
            if (type == null) return Array.Empty<ExplorerTrackerState>();
            var name = AccessTools.Field(type, "m_resourceName");
            var range = AccessTools.Field(type, "m_trackRange");
            var level = AccessTools.Field(type, "m_requiredLevel");
            if (name == null || range == null || level == null) return Array.Empty<ExplorerTrackerState>();
            return UnityEngine.Object.FindObjectsByType(type, FindObjectsSortMode.None).OfType<Component>().Select(t =>
                new ExplorerTrackerState { resourceName = (string)name.GetValue(t), range = (float)range.GetValue(t),
                    requiredLevel = (int)level.GetValue(t), x = t.transform.position.x, y = t.transform.position.y, z = t.transform.position.z }).ToArray();
        }
        catch { return Array.Empty<ExplorerTrackerState>(); }
    }

    /// <summary>The local platform user ID, "steam_7656…" on the test client; empty before platform sign-in.</summary>
    private static string PlatformUserId()
    {
        try { return Splatform.PlatformManager.DistributionPlatform?.LocalUser?.PlatformUserID.ToString() ?? ""; }
        catch { return ""; }
    }

    /// <summary>The numeric Steam ID for adminlist.txt, parsed from the platform user ID.</summary>
    private static string SteamId() =>
        Splatform.PlatformUserID.TryParse(PlatformUserId(), out Splatform.PlatformUserID parsed) && parsed.TryParseAsUInt64(out ulong id)
            ? id.ToString() : "";

    private static bool ObservedAdmin()
    {
        if (ZNet.instance == null) return false;
        // Jotunn sends the server-authoritative admin status separately; full-Pack mods may
        // leave vanilla's client AdminList empty. Minimal installs have no Jotunn assembly.
        Type? type = Type.GetType("Jotunn.Managers.SynchronizationManager, Jotunn", throwOnError: false);
        if (type == null) return ZNet.instance.LocalPlayerIsAdminOrHost();
        object instance = AccessTools.Property(type, "Instance").GetValue(null);
        return (bool)AccessTools.Property(type, "PlayerIsAdmin").GetValue(instance);
    }

    /// <summary>
    /// Visible UI: every active direct child of every enabled root canvas, as one window each, with
    /// its texts and its buttons under the same observed IDs the <c>ui</c> action clicks. Valheim's
    /// own panels are marked <c>custom:false</c> so scenarios can pick plugin windows without
    /// naming mods.
    /// </summary>
    private List<WindowState> Windows()
    {
        List<WindowState> windows = new();
        foreach (Canvas canvas in UnityEngine.Object.FindObjectsByType<Canvas>(FindObjectsInactive.Exclude, FindObjectsSortMode.None))
        {
            if (!canvas.isRootCanvas || !canvas.isActiveAndEnabled || canvas.renderMode == RenderMode.WorldSpace) continue;
            foreach (Transform child in canvas.transform)
            {
                if (!child.gameObject.activeInHierarchy) continue;
                List<string> texts = new();
                foreach (TMPro.TMP_Text text in child.GetComponentsInChildren<TMPro.TMP_Text>(false))
                {
                    if (text.text.Length == 0 || texts.Contains(text.text)) continue;
                    texts.Add(text.text.Length > 200 ? text.text.Substring(0, 200) : text.text);
                    if (texts.Count >= 24) break;
                }
                foreach (UnityEngine.UI.Text text in child.GetComponentsInChildren<UnityEngine.UI.Text>(false))
                {
                    if (text.text.Length == 0 || texts.Contains(text.text)) continue;
                    texts.Add(text.text.Length > 200 ? text.text.Substring(0, 200) : text.text);
                    if (texts.Count >= 48) break;
                }
                List<ButtonState> windowButtons = new();
                foreach (UnityEngine.UI.Button button in child.GetComponentsInChildren<UnityEngine.UI.Button>(false))
                {
                    string id = button.GetInstanceID().ToString();
                    buttons[id] = button;
                    TMPro.TMP_Text label = button.GetComponentInChildren<TMPro.TMP_Text>(true);
                    UnityEngine.UI.Text legacyLabel = button.GetComponentInChildren<UnityEngine.UI.Text>(true);
                    windowButtons.Add(new ButtonState { id = id,
                        text = label != null ? label.text : legacyLabel != null ? legacyLabel.text : button.name,
                        active = true, interactable = button.IsInteractable() });
                }
                if (texts.Count == 0 && windowButtons.Count == 0) continue;
                string name = child.gameObject.name;
                windows.Add(new WindowState { canvas = canvas.gameObject.name, name = name, order = canvas.sortingOrder,
                    custom = !VanillaPanels.Contains(name.ToLowerInvariant()), texts = texts.ToArray(), buttons = windowButtons.ToArray() });
            }
        }
        return windows;
    }

    private void Publish(string name, object value)
    {
        string path = Path.Combine(directory, name);
        string temporary = path + ".tmp";
        File.WriteAllText(temporary, JsonConvert.SerializeObject(value, Formatting.Indented));
        if (File.Exists(path)) File.Replace(temporary, path, null);
        else File.Move(temporary, path);
    }

    private sealed class Request
    {
        public string id = "", action = "", target = "", item = "", recipe = "", method = "", text = "";
        public float x = 0, y = 0, z = 0, seconds = 0, yaw = 0;
        public bool secondary = false, value = false;
    }
    private sealed class Status { public bool ready; public string error = ""; }
    private sealed class Response { public string id = "", error = ""; public bool ok; public State? state; }
    private sealed class State
    {
        public PlayerState player = null!;
        public ItemState[] inventory = null!;
        public EntityState[] entities = null!;
        public TextState[] progression = null!, customData = null!;
        public SkillState[] skills = null!;
        public MessageState messages = null!;
        public RecentLine[] recentMessages = Array.Empty<RecentLine>(), chat = Array.Empty<RecentLine>();
        public WindowState[] windows = Array.Empty<WindowState>();
        public MapPinState[] mapPins = Array.Empty<MapPinState>();
        public ExplorerTrackerState[] explorerTrackers = Array.Empty<ExplorerTrackerState>();
        public UiState ui = null!;
        public bool admin;
        public string platformUserId = "", steamId = "";
        public string[] adminList = Array.Empty<string>();
        public string localUserId = "";
        public ConsoleState? console;
        public HarnessKeys.KeyResult? keyPress;
        public string connection = "", fixtureSpawned = "", fixtureZdo = "";
        public string[]? fixturePrivateKeys;
        public FoodState[] foods = Array.Empty<FoodState>();
        public EffectState[] statusEffects = Array.Empty<EffectState>();
    }
    private sealed class MapPinState { public string name = "", type = ""; public bool save; public float x, y, z; }
    private sealed class ExplorerTrackerState { public string resourceName = ""; public float range, x, y, z; public int requiredLevel; }
    private sealed class PlayerState
    {
        public string id = "", name = "", biome = "";
        public float x, y, z, health, maxHealth, stamina, maxStamina, eitr, maxEitr, waterLevel, terrainHeight, weight, maxCarry;
        public bool dead, pvp, swimming;
    }
    private sealed class ItemState { public string id = "", prefab = "", name = "", tooltip = ""; public int stack, quality, x, y; public bool equipped; public TextState[] customData = null!; }
    private sealed class FoodState { public string name = ""; public float time, health, stamina, eitr; }
    private sealed class EffectState { public string name = "", label = ""; public float remaining; }
    private sealed class EntityState { public string id = "", prefab = "", name = ""; public float x, y, z, health, maxHealth; public bool isPlayer, interactable; }
    private sealed class TextState { public string key = "", value = ""; }
    private sealed class SkillState { public int type; public string name = ""; public float level, accumulator, effective; }
    private sealed class MessageState { public string center = "", topLeft = ""; }
    private sealed class RecentLine { public string where = "", text = ""; public float unscaled; public string time = ""; }
    private sealed class WindowState { public string canvas = "", name = ""; public int order; public bool custom; public string[] texts = null!; public ButtonState[] buttons = null!; }
    private sealed class ConsoleState { public string command = ""; public string[] lines = null!; }
    private sealed class UiState { public bool inventory, map, crafting, craftEnabled; public string[] recipes = null!; public ButtonState[] buttons = null!; }
    private sealed class ButtonState { public string id = "", text = ""; public bool active, interactable; }
}
