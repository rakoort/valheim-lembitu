# PvP: stance and tombstone access

Why the Run writes its own PvP rules, what was decided and what the game and the pinned mods
actually do. The rules players experience are in [The Run: concept and rules](../rules.md) under
"PvP and death"; the contract being built is `issue://67`. Terms are `CONTEXT.md`: a **Stance** is a
character's standing choice to be open to player-versus-player combat, a **Tombstone** is what a
death leaves behind.

## Decisions

Settled with the owner on 2026-09-16, in one interview. Each entry names the alternative that lost,
because the alternatives are what a future reader will wonder about.

- **The permitted places are the sacrificial stones and your own clan's ward.** Not boss summoning
  altars, which were the first proposal: the owner chose the spawn stones instead, so re-arming is a
  trip home rather than a pilgrimage to a boss. Not `Vegvisir`, of which there are hundreds, because
  a gate you can always reach is not a gate. Another clan's ward never counts, even for a Guest who
  may build there.

- **20 m, the whole circle of stones.** The tighter 8 m interaction range was offered and rejected as
  fiddly; the 64 m spawn clearing was rejected as too loose, since a player merely passing through
  spawn could flip without stopping.

- **Guest clans count inside a ward.** Rejected: primary-only, which would have created a second,
  narrower membership rule that Clan does not express and ADR-0008 forbids inventing.

- **Both directions are place-bound.** Rejected: free un-flagging anywhere, which restores the button
  — flag up, hunt, drop the flag when losing. Also rejected: unflagging on death, which would make
  every corpse run safe.

- **The stance persists, server-side, per character** (ADR-0013). Rejected: the character file, which
  is client-owned and editable (ADR-0010); and vanilla's behaviour, where every session starts
  unflagged and logging out is a free escape. Per account was rejected because every other rule in
  the run is per character.

- **Place is the only friction.** Rejected: a cooldown between changes, and a delayed activation.
  Both need a second persisted value and neither is explainable in a centre message.

- **An unflagged tombstone opens for the victim's clan.** Rejected: strictly private, which strands a
  full set of gear in the Mistlands until the owner walks back. The clan is the one recorded at the
  moment of death, resolved from the active clan, so a clan cannot recruit a player afterwards to
  reach a tombstone and a victim who switches clan does not lose their own body.

- **A flagged tombstone opens for flagged players only.** Rejected: anyone, which lets a permanently
  unflagged player farm PvP corpses from safety. Killer-only is not a choice at all — see the facts
  below.

- **The five-minute post-death grace stays at five minutes.** It blocks damage, not stance changes,
  so it does not overlap the new rule.

- **Handshake-enforced, no admin bypass, every number in enforced config.** Rejected: server-side
  only, where a client without the plugin finds the toggle mysteriously inert; an admin bypass, which
  turns the rule into a courtesy; and constants in the plugin, where retuning a radius costs a
  rebuild, a Pack reissue and a client re-extract.

## Facts

These are read from binaries and a catalogue, not decided. Full attribution in
[Research provenance](../research.md).

**Nothing published does this.** The Thunderstore Valheim index, 11,269 packages fetched 2026-09-16,
contains no mod that restricts where or how often a stance changes, and none that scopes corpse
access to the dead player's flag. That is what makes ADR-0012's exception to ADR-0003 and ADR-0010
an addition rather than a reimplementation.

**Vanilla keeps the flag nowhere durable.** `Player.SetPVP` writes `ZDOVars.s_pvp` on the player's
own ZDO; `PlayerProfile` stores nothing. So the flag is already off at every login, and the
persistence in ADR-0013 closes a hole rather than adding a restriction.

**Vanilla already gates the toggle, and greys it.** `Player.CanSwitchPVP()` returns
`m_lastCombatTimer > 10f`, and `InventoryGui` sets `m_pvp.interactable` from it every frame. That is
the seam for a place predicate — with a server-side guard beside it, because the UI check runs on the
client.

**"Boss runestone" is three different objects.** `OfferingBowl` is the summoning altar and carries
`m_bossPrefab`; `Vegvisir` is the stone that reveals a boss location on the map; `BossStone` is the
power stone at the sacrificial stones. Detect the permitted place by component, never by a
prefab-name list, which is also what survives a game update.

**Only the killer is unimplementable.** PvPBiomeDominions patches `Player.CreateTombStone`, which
takes no killer, so the tombstone cannot learn who caused the death. The same patch is why retention
is death-cause blind: a flagged player who drowns keeps their gear.

**Retention already reads the victim; only access reads the looter.** The `CreateTombStone` prefix
keeps an item when `m_equipped` with keep-equipped on, or when `m_gridPos.y == 0` — the vanilla
hotbar row and nothing else — with keep-hotbar on. The looting restriction lives in a
`Container.Interact` prefix instead, judged per acting player, which is the bug this work fixes.

**Membership and the claim have real APIs.** `ClanApi.ResolveMemberships` and
`ClanApi.ResolveWardAuthorization` answer primary and Guest membership from a platform id and a
character player id; `WardAccessApi.IsManagedWard` and `TryCheckContainerAccess` answer the ward
claim. ADR-0008 stays intact: nothing compares identifiers.

## Known constraint on proving it

Both test hosts share one Steam account (`ap3l5in`), and Valheim cannot run the same account in two
places at once. Every criterion in `issue://67` that needs two players at the same time — tombstone
access, and the inherited slot-retention checks from #74 — is blocked on a second licence. This is
the same constraint `docs/build.md` records against the outstanding simultaneous two-client
acceptance; it is a prerequisite, not a scheduling problem.
