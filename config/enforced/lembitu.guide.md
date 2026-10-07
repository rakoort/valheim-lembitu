# Lembitu guide - the server's in-game rulebook (ADR-0027, ADR-0028).
#
# The server sends this file's pages to every client at join and when it reloads; a client's own
# copy is never used while connected. Edit it on the server and save: connected clients get the
# new pages within a few seconds of the file changing.
#
# Each page starts with "page <id> | <Title>" and runs to the next page line. Blank lines split
# paragraphs; lines starting with '#' are comments. The page ids are fixed - refusal messages and
# other plugins name them, so do not rename or drop them: first-steps, oath-and-class, calling,
# ladder, boss-keys, groups, death.

page first-steps | First steps
Welcome to Lembitu.

This server is built for keyboard and mouse. Controllers are not supported.

Every new player wakes at the sacrificial stones, where the Oathstone stands. The first evening is shared there: meet the other guilds, take an oath, choose a Calling, found a guild and claim a start region.

F9 opens the guild window. Use FOUND A GUILD to found one for free, INVITATIONS to accept an invitation, or GUILD LIST to apply to a guild. A guild leader whose guild holds no region claims a free start region at its portal stone beside the sacrificial stones; use it and confirm.

Open this guide any time with F1 or the Guide button in your inventory.

No oath, no class XP: kills pay nothing toward a class until you have sworn one at the Oathstone.

Keys: F1 Guide; F7 Market; F9 Guilds; O social; P party; Left Alt+E hides or shows Explorer markers.

page oath-and-class | Oath and class
Your class comes from Oathbound, chosen at the Oathstone. Thirteen classes exist; four unlock after a first deed - equip paired axes, a two-handed sword or a two-handed axe, or carry a dragon tear.

Kills earn class XP only once you have taken an oath. A kill pays about twice the square root of its maximum health, four times that from a boss. Every level grants a talent point, to level 80.

Take your first oath, switch class or Reset talents at the Oathstone. After your first oath the inventory Classes button opens the talent tree anywhere, and you may spend points there. Your Calling still changes only at the stone.

Each class keeps its own level, XP and talents when you switch. Reset talents is free at the Oathstone: it returns points without losing levels or XP. You level one class at a time. Levels lost to switches before Pack v17 cannot be restored.

Classes keep their equipment rules - mages wear no metal armour, shieldbearers carry no bow - except that every class may use the fishing rod, and a Monk's bare hands train Mining and Wood Cutting.

A Hunter orders the wolf with Y: free hunt, stay, heel or recall. Stay and heel keep it out of fights it would otherwise start; recall breaks off a fight at once.

BetterArchery adds a quiver, bow zoom and retrievable arrows. Gameplay is server-locked at the mod defaults; zoom, hotkeys, quiver layout and visuals remain yours. Ranger True Flight and Snapshot stack above its arrow speed. Removing BetterArchery loses arrows held in its quiver.

page calling | Calling
Your Calling is four focus professions: two Land, one Craft, one Road.

Open the Calling window from the Calling button in the skills window. Read it anywhere; choose or change focuses only at the Oathstone. The stars on the profession rows are read-only markers. Dropping a focus asks first and names the level the skill falls to.

A focus levels at full speed to 100. Every other profession levels at full speed to 10, at half speed to 60, a quarter to 80 and a tenth beyond. Nothing is capped: a non-focus skill needs about twice the work to reach 20 to 60 and six times to reach 100.

Until you choose, every profession follows the slow curve, which changes nothing below 10.

A focus keeps its XP when you die. Dropping a focus costs what it gave: the skill falls to its hidden, slower level.

Every skill gain shows for a moment above your health bar, with the progress to the next level, so you can watch a focus outpace a non-focus skill.

Wood Cutting, Fishing and Hauling each gain a milestone at 50. Wood Cutting: a chop can split a whole fallen log into wood. Fishing: fish come to your float sooner. Hauling: walking over your carry limit costs no stamina, up to one and a half times the limit. Mining, Farming, Animal Handling and Sailing have theirs between 40 and 70; Exploration's markers unlock biome by biome.

Road is Explorer (Exploration), Sailing and Hauling. Explorer reveals more of your personal map as it grows, from 100 m to 400 m at 100. Its temporary resource markers unlock at Meadows 1, Black Forest 10, Swamp 20, Mountains 30, Plains 40, Mistlands 50 and Ashlands 60; dungeons and caves at 10. Marker reach grows from 20 m at level 1 to 96 m at 100. These are Exploration perks, not crafting gates. BetterMap does not add automatic resource pins.

page ladder | Profession benefits
Professions give benefits, not crafting blocks. Anyone may craft a recipe they know, whatever their profession level; personal boss keys still apply to crafting and use. Baits, saddles, backpacks, the scythe, elixirs and ship parts have no profession-level requirement.

A focus earns stronger perks sooner and keeps its XP on death. Other professions still follow the steep curve: there is no profession cap and no recipe ladder to climb.

The smith is the guild's armourer: each 10 Blacksmithing levels adds 2% damage, 1 armour and 2 block power to the gear they make. The cook makes stronger, longer-lasting dishes; the alchemist makes better drinks. A specialist's goods keep their grade through the Market.

Meads, Herbalist tonics and elixirs carry the brewer's grade: grade 1 below Herbalist 25, then one more per 25 levels, 5 at 100. Only the brewer's real level counts, never bonuses from meals, gear or elixirs. A graded mead base keeps its grade through fermentation; grades stack separately and show in the tooltip. Old or looted drinks without a grade count as grade 1.

The drinker's Herbalist skill no longer changes a drink. Tonic and elixir durations grow from normal at grade 1 to 1.75 times at grade 5. Healing, stamina and eitr mead cooldowns are 10% shorter at grade 1, rising to 80% shorter at grade 5. Resistance, Tasty and Lingering meads last 1.25 times as long at grade 1, rising to twice as long at grade 5; there is no one-hour minimum. Herbalist's tonic tiers stay at 1, and tonic drinking still requires the matching personal boss key.

page boss-keys | Boss keys
This server writes no world keys. Boss unlocks are personal, stored on your character.

Presence earns a key, not damage: when a boss dies, everyone within 100 m of it gets the key, and nobody else. Guilds do not share keys with absent members.

A key unlocks a biome's gear for crafting, wearing, cooking, eating, guardian powers and boss summons. Not locked: repairs, building, taming, boats and portals. Every lock follows the biome of the item's materials. Deep North gear and its Frost Foundry uncooked intermediates require your personal Fader key to craft and equip. Baits and Herbalist herbs have no added key lock; tonic drinking keeps its own key checks.

Trade helps, but never skips a boss. A late joiner catches up by being carried through re-kills.

Boss powers are passive and grow with every boss kill you attend.

page groups | Guilds, parties and the Market
A guild is who you belong to: ranks, guild chat, a shared vault, wards, a banner territory and guild levels. At most five members, at most three guilds. Founding one is free.

Press F9 to open the guild window. FOUND A GUILD starts your own guild; INVITATIONS lets you accept an invitation; GUILD LIST lets you apply to a guild and wait for approval.

Guilds claim their start regions in game. Everyone starts at the sacrificial stones. A guild leader whose guild holds no region claims an unclaimed start region by using that region's portal stone in the ring around the stones, after a confirmation window names the region and shows where it lies. The hover text explains who can claim it; a claimed portal names its guild. One region per guild, first come, first served.

The region follows membership: joining a guild makes its region your respawn point and gives you its portal; leaving a guild sends you back to the stones; a disbanded guild frees its region. A bed you place overrides the respawn, as usual.

A party is who you hunt with: invite-only, up to eight, and it may mix guilds. It shares exactly two things: map positions and kill XP.

Kill XP goes to the killer's party, and only to members within 100 m of the creature when it dies. Being in a party never waives proximity.

The Market is server-wide and works while the other side is offline: coin sales, buy orders, bounties and a bank, with a 5% fee on every payout.

page death | Death
Deaths are meant to cost something.

Class XP: you lose half your progress into the current class level, never a level.

Skills: each non-focus skill loses 5% of its level, but only above your skill floor. The floor rises by 10 for every personal boss key you hold and never raises a skill. Focus professions lose nothing.

Your tombstone holds what vanilla death rules take; you go back for it. Carried items and durability are otherwise untouched.

page food | Food and the cook
Food spoils. Most dishes keep two to four days of server time, and the time left shows on the dish. Fresh food gives 10% more than usual; stale food gives about 17% less. Eat it fresh.

Jerky, sausages, smoked fish, smoked moose meat and honey never spoil: take them on trips. Nothing spoils in the Mountains or the Deep North, and an Icebox, built from Mountains materials, stops the clock at home.

A dish carries its cook's grade: grade 1 below Cooking 25, then one more per 25 levels, 5 at 100. Only the cook's real level counts. Each grade above 1 adds 5% to everything the dish gives and 12.5% to how long it keeps: grade 5 gives 20% more and keeps 50% longer. A graded dough or uncooked pie keeps its grade in the oven. Grades stack separately, survive the Market and show on the dish.

Work meals: while one of these is among your foods, a profession counts as 10 levels higher for its perks, never for the cook's or brewer's grade. Boar jerky: Exploration. Deer stew: Wood Cutting. Sausages: Mining. Carrot soup: Farming. Serpent stew: Sailing. Wolf jerky: Hauling. Blood pudding: Animal Handling. Fish wraps: Fishing.
