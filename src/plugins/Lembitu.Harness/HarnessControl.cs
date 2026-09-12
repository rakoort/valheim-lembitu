using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using BepInEx.Logging;
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
    private string fixtureSpawned = "";

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
                if (parsed.action != "quit" && !ready) throw new InvalidOperationException("harness is not ready");
                operation = Execute(parsed);
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
                GameObject target = Target(command.target);
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
                GameObject spawned = UnityEngine.Object.Instantiate(prefab, position, Quaternion.identity);
                fixtureSpawned = spawned.GetInstanceID().ToString();
                yield return null;
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
    private string ItemId(ItemDrop.ItemData item)
    {
        if (!itemIds.TryGetValue(item, out string id)) itemIds.Add(item, id = (++nextItem).ToString());
        return id;
    }

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
                health = player.GetHealth(), dead = player.IsDead(), pvp = player.IsPVPEnabled() },
            inventory = player.GetInventory().GetAllItems().Select(i => new ItemState { id = ItemId(i), prefab = i.m_dropPrefab != null ? i.m_dropPrefab.name : "",
                name = i.m_shared.m_name, stack = i.m_stack, equipped = i.m_equipped, x = i.m_gridPos.x, y = i.m_gridPos.y }).ToArray(),
            entities = nearby.ToArray(),
            progression = player.m_knownTexts.Select(k => new TextState { key = k.Key, value = k.Value }).ToArray(),
            ui = new UiState { inventory = InventoryGui.IsVisible(), map = Minimap.IsOpen(), crafting = gui != null && gui.m_craftTimer >= 0,
                buttons = buttonStates.ToArray(), craftEnabled = gui != null && gui.m_craftButton.IsInteractable(),
                recipes = gui == null ? Array.Empty<string>() : gui.m_availableRecipes.Select(r => r.Recipe.name).ToArray() },
            connection = ZNet.instance == null ? "absent" : ZNet.GetConnectionStatus().ToString(),
            fixtureSpawned = fixtureSpawned
        };
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
        public string id = "", action = "", target = "", item = "", recipe = "";
        public float x = 0, y = 0, z = 0, seconds = 0;
        public bool secondary = false, value = false;
    }
    private sealed class Status { public bool ready; public string error = ""; }
    private sealed class Response { public string id = "", error = ""; public bool ok; public State? state; }
    private sealed class State
    {
        public PlayerState player = null!;
        public ItemState[] inventory = null!;
        public EntityState[] entities = null!;
        public TextState[] progression = null!;
        public UiState ui = null!;
        public string connection = "", fixtureSpawned = "";
    }
    private sealed class PlayerState { public string id = "", name = ""; public float x, y, z, health; public bool dead, pvp; }
    private sealed class ItemState { public string id = "", prefab = "", name = ""; public int stack, x, y; public bool equipped; }
    private sealed class EntityState { public string id = "", prefab = "", name = ""; public float x, y, z, health; public bool isPlayer, interactable; }
    private sealed class TextState { public string key = "", value = ""; }
    private sealed class UiState { public bool inventory, map, crafting, craftEnabled; public string[] recipes = null!; public ButtonState[] buttons = null!; }
    private sealed class ButtonState { public string id = "", text = ""; public bool active, interactable; }
}
