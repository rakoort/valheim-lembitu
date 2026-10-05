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

Class, talents and your Calling change only at the Oathstone.

Respec and switching class cost the class level: the class you leave and the class you take both start over at level 1. You level one class at a time.

Classes keep their equipment rules - mages wear no metal armour, shieldbearers carry no bow - except that every class may use the fishing rod, and a Monk's bare hands train Mining and Wood Cutting.

page calling | Calling
Your Calling is four focus professions: two Land, one Craft, one Road.

Open the Calling window from the Calling button in the skills window. Read it anywhere; choose or change focuses only at the Oathstone. The stars on the profession rows are read-only markers. Dropping a focus asks first and names the level the skill falls to.

A focus levels at full speed to 100. Every other profession levels at full speed to 30, at half speed to 60, a quarter to 80 and a tenth beyond. Nothing is capped: a non-focus skill needs about 1.8 times the work to reach 60 and nearly six times to reach 100.

Until you choose, every profession follows the slow curve, which changes nothing below 30.

A focus keeps its XP when you die. Dropping a focus costs what it gave: the skill falls to its hidden, slower level.

Road is Explorer (Exploration), Sailing and Hauling. Explorer reveals more of your personal map as it grows, from 100 m to 300 m at 100. Its temporary resource markers unlock at Meadows 1, Black Forest 10, Swamp 20, Mountains 30, Plains 40, Mistlands 50 and Ashlands 60; dungeons and caves at 10. Marker reach grows from 20 m at level 1 to 64 m at 100. BetterMap does not add automatic resource pins.

page ladder | Profession ladder
What a profession makes climbs ten levels per biome: Black Forest 10, Swamp 20, Mountains 30, Plains 40, Mistlands 50, Ashlands 60, Deep North 70. Meadows asks nothing.

Only crafting is gated, never use. Anyone may wear, wield, drink or buy what a specialist made. Repairs, ammunition, the hammer, hoe and cultivator and utility items stay open to everyone.

Blacksmithing gates every weapon, shield and armour piece. Herbalist gates mead bases and tonics, Cooking the crafted dishes, Fishing the biome baits, Animal Handling saddles, Hauling backpacks, Farming the scythe.

From the Plains on, a crafter without the focus needs 1.5 times the skill XP at 40, rising to 2.5 times at 70.

The smith is the guild's armourer and the alchemist its apothecary. A master smith's gear is a little better: +1% damage, +0.5 armour and +1 block power per 10 Blacksmithing levels.

page boss-keys | Boss keys
This server writes no world keys. Boss unlocks are personal, stored on your character.

Presence earns a key, not damage: when a boss dies, everyone within 100 m of it gets the key, and nobody else. Guilds do not share keys with absent members.

A key unlocks a biome's gear for crafting, wearing, cooking, eating, guardian powers and boss summons. Not locked: repairs, building, taming, boats and portals. Every lock follows the biome of the item's materials.

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
