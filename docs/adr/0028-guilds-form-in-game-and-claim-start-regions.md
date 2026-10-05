# ADR-0028: Guilds form in game and claim start regions

Date: 2026-10-05
Status: Accepted; not yet implemented
Amends: ADR-0018 (separate starts), ADR-0019 (guilds agreed before launch), ADR-0022 (our plugins)

ADR-0019 had guilds agreed before launch and each guild's members rostered by Steam ID into one of
SeparateSpawns' three scored start regions. The owner wants guilds formed in game instead
(2026-10-05). SeparateSpawns 0.1.1 assigns any player missing from its roster to a random region at
first join and has no setting to stop it (`GroupSpawnResolver.cs:158-177`); its regions each have a
portal in a ring 28 m around the sacrificial stones, opened with 2 Surtling cores (`ModConfig.cs:85-86`).

**Decision.** Every new player wakes at the sacrificial stones, beside the Oathstone, so the first
evening is shared: meet, take an oath, choose a Calling, found guilds (founding is free). A founded
guild's leader claims an unclaimed start region by using that region's portal stone in the ring, after
a confirmation window naming the region and showing where it lies; first come, first served. The region
follows guild membership: joining a guild makes its region the member's respawn point and gives them
its portal, leaving sends the player back to the stones, and a guild that disbands frees its region.
A bed overrides the respawn point, as in vanilla. With three regions, at most three guilds hold one.

A new plugin, `Lembitu.Guilds`, owns the bridge: it holds back SeparateSpawns' random placement for
players outside a guild, assigns a guild's members to its region, handles the claim at the portal and
reads membership from Northarun/Guilds. Only SeparateSpawns or Guilds updates re-check it.

**Rejected.** Random regions with guilds forming anywhere needed no code but left regions meaningless
to guilds. A shared start without regions dropped the scored, fair starts and the moment of first
contact between guilds. A region that sticks to a player's first assignment would split guilds; claims
that outlive a disbanded guild would lock a region forever. Placing the bridge in `Lembitu.Guide` would
make the guide re-check on every SeparateSpawns and Guilds bump.
