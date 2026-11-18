# Legends of Madlands RPG - Design Doc

Source of truth lives in the shared Claude doc. This is a copy for the code project. Last synced: 2026-11-19.

## 1. Vision and player goals

Madlands is a fantasy RPG on Roblox where players bond, own their character, and always have something to do. It is a sandbox-lite: free to roam and fight, but with quests, story and structure.

- **Social first:** a place to meet, party up, trade and hang out.
- **Ownership:** players feel their character is theirs through weapons, chosen skills and cosmetics.
- **No locked classes:** change fighting style without restarting, like Albion Online.
- **Always something to do:** PvP, trading, badge hunting, leaderboards, pet collecting.

**Working title:** Legends of Madlands [RPG] (short name: Madlands). Why: "Madlands" carries the creator's nickname Mads, "Legends" fits the story and quest focus, and [RPG] tells players the genre.

## 2. Core pillars

| Pillar | How it works | Why |
| --- | --- | --- |
| Classless weapons | Your weapon defines your style. Swap weapons and keep each weapon's progress. | Freedom to change playstyle without restarting. |
| Skill collecting | Skills are bought, traded, earned or found in specific places. | Gives exploration and trading a purpose. |
| Fair PvP | Level and gear scale inside each zone. Death costs gold only. | Keeps new players in the game and PvP fun. |
| Pet collecting | Up to 150 pets over time, catchable in the open world. | Pokemon-style goal that keeps players collecting. |
| Big seamless world | Separate places linked by gates and teleports that feel connected. | Large areas without Roblox performance problems. |

## 3. Weapons

- **Few base weapons (about 6-8)**, for example sword, greatsword, bow, staff, dagger, spear, gauntlets, tome. Why: fewer models means more time for skins, which fits the cosmetic ownership goal.
- **Weapon is the class.** Each weapon keeps its own mastery level, so switching back costs no grind.
- **Two weapons once a certain level is reached**, with a quick-swap key. Why: lets players mix styles and builds a personal identity.
- **Weapon skins** are the main cosmetic and limited-release item.
- **Mastery** per weapon unlocks skill upgrades and the ultimate slot.

Ideas to decide later: split each weapon into 2 paths at mid level; combo skill triggered when swapping weapons.

## 4. Skills

- **4 free base skills per weapon.** Everything else is acquired.
- **Ways to get more skills:** buy from trainers in cities, trade or buy from players, quests, titles, limited Robux releases.
- **Location and level locked:** some skills are sold only in certain places for a certain level range. Why: gives exploration a purpose and gets players talking about where things are.
- **Skill scrolls** are tradeable until learned, then bound to the player. Why: keeps the player market alive.
- **Loadout limit** (suggested: 4 active + 1 ultimate per weapon). Why: a big collection but a real build choice.
- **Upgrades:** mastery raises skill tiers (I, II, III).
- **Limited and Robux skills are sidegrades:** same power, different look or behavior. Why: people pay for style and the game stays out of pay-to-win.

## 5. Leveling and level sync

Problem to solve: a level 50 should not be an unbeatable wall for a level 20.

- **Zone level sync (main fix):** each zone has a level cap. Higher-level players are scaled down to it.
- **Flat power curve:** a level 50 is about 1.5x stronger than a level 20, not 10x. Most power comes from skills, mastery and play.
- **Skill-based combat:** dodge, block/parry and telegraphed attacks let skill beat level.
- **Gear cap per zone:** gear stats scale down in lower zones. Special effects and skins stay. Endgame gear keeps full power in the top zone and dungeons, plus a small edge (+5-10%) elsewhere. Why: it still feels rewarding but cannot be used to bully newcomers.
- **Arena (if added):** everyone normalized to the same level and base stats.

**Progression tracks:** character level has a hard cap that can be raised with new regions, and weapon mastery continues after it. XP comes from a mix: story quests lead early on, with mob grinding, events and dungeons taking over later.

| Zone | Level range | Syncs to |
| --- | --- | --- |
| Greenfields (guarded) | 1-15 | 15, PvP off under level 10 |
| Wolf Forest | 15-25 | 25 |
| Desert Ruins | 25-40 | 40 |
| Lawless Wilds | 40+ | no sync, warning on entry |

**Unsynced zone:** Lawless Wilds is the only unsynced zone. Players get a clear warning before entering, because level and gear apply at full power there. Why: max-level players get a real endgame PvP zone, and everyone else knows the risk up front.

## 6. World and zones

- **Cities and outside areas are separate places.** Players travel through a gate, and a loading screen reloads the page to the next place. Why: keeps each map light on Roblox while the world still feels connected.
- **Cities are safe** hubs: trainers, shops, banks, trading, social spaces.
- **Outside areas are wide**, with both PvE and PvP spread out so they never feel crowded.
- **Zone tiers:** safe city, guarded fields (some PvP rules), lawless wilds (free PvP).
- **Campfire rest spots** in the wild act as small social hubs.
- **Things to do:** PvP, trading, badge collecting, ranked leaderboards, pet collecting, quests.

**Draft region names:** Madlands Greenfields (starter), Howling Woods (wolves), Sunscar Ruins (desert), The Deep Madlands (lawless endgame).

## 7. PvP and player killer system

- **PvP only in outside areas.** New players are protected (no PvP under about level 10-15, or limits across big level gaps).
- **Death penalty: gold only, no item loss.** Why: losing gear (as in Albion) makes casual players quit, and the goal is bonding and enjoyment.
- **Pocket gold vs bank gold:** only carried gold can drop. Bank gold is safe. Players choose between carrying gold into the wild and staying safe.
- **Optional trip loot:** materials gathered on that trip can drop. Gear, skills, pets and cosmetics are never lost.
- **Kill counter and titles:** players see how many players someone has killed. Titles give a buff in some areas and a nerf in others, so players can choose not to be a PK.
- **Bounty Hunters:** killing PKs earns Honor and titles, giving non-PKs a role.
- **Anti-abuse:** no gold drop when levels differ by 10+, and a 5-minute lock on repeat looting by the same killer.

| Status | Kills | Pocket gold dropped on death | Notes |
| --- | --- | --- | --- |
| Normal | 0 | 25% | |
| Rogue | 1-4 | 40% | Red name. Buff: +5% loot from PvP kills |
| Outlaw | 5-14 | 60% | Nerf: guards attack, shop prices up. Buff: outlaw camp shop |
| Warlord | 15+ | 80% | Nerf: bounty pays the killer. Buff: extra damage in Lawless Wilds |

Drops are deliberately high so death hurts, and the higher the infamy the more a PK can lose and the more the killer earns. Each title pairs a buff with a nerf so it is both rewarding and punishing. Numbers are a starting draft and need testing. Infamy should decay over time or be removable by a quest.

## 8. Pets

- **Goal:** up to 150 pets, Pokemon-style. Why: collecting keeps players engaged and pets are part of player identity.
- **Launch smaller:** start with 30-40 using evolution families (for example 12 families x 3 stages) to save art work.
- **Roles:** fighter, support, gatherer, mount.
- **Catching:** weaken the mob, then use a capture item. Rare variants for collectors.
- **Pet Dex** with badges for completing regions.
- **Bond level** makes a pet stronger and can unlock combo skills.
- **Open world:** pets fight mobs and players. In world PvP they deal reduced damage and are knocked out, never permanently lost.
- **PvP arena:** pets are not allowed. Pure player skill.
- **Decided against:** a separate pet-vs-pet arena.

## 9. Mobs and world events

- **Mobs attack automatically** when a player enters their area.
- **Two types:** solo mobs that are strong alone, and group mobs (goblins, wolves) that are strong in numbers. Why: groups push players to team up, which supports the bonding goal.
- **Party bonuses:** extra XP and shared loot for groups.
- **World events (idea):** goblin raids or a wandering world boss announced server-wide, so strangers cooperate.

## 10. Economy, trading and monetization

- **Player trading** for skill scrolls, items and materials.
- **Gold** is the main currency and the only thing lost on death.
- **Time-limited items and skills** are allowed but must not be overpowered. Some limited items and skills can also be bought with in-game gold, not only Robux, so free players can still get limited content and the game stays fair.
- **Robux:** sell cosmetics, skins, pet variants, titles and sidegrade skills. Do not sell raw power. Why: pay-to-win drives players away.
- **Duplication protection:** save data safely and make trades server-checked.

## 11. Story and quests

- **Decent storyline for every quest.**
- **One main story arc per region**, with side quests filling in lore.
- **Draft lore hook:** Mads was a legendary wanderer who first tamed the wild beasts, and the lands carry his name. A world mystery can explain why mobs attack and why pets can be caught.
- Quests can reward skills, titles, gold and pets.

## 12. Tech and team setup

- **One Roblox experience with many places** (city, forest, desert, wilds), connected with TeleportService. Use gate animations and a custom loading screen so the jump feels seamless. Parties teleport together.
- **Data saving** with ProfileStore/ProfileService.
- **Server-authoritative combat and trading**, because exploiters target PvP and trades first.
- **Team:** friends are co-developers. Use a shared studio/group (ideas: Mad Forge Games, Guildhall Studios) with Team Create and roles (builder, scripter, designer, modeler). Give edit access only to trusted people.
- **Agree early:** Robux split, who has final say, and in-game credits for everyone.
- **Easter eggs:** each developer gets an NPC, weapon or landmark named after them.

## 13. MVP scope and open questions

**Suggested first playable version**

1. 1 city + 2 outside zones (1 guarded, 1 lawless)
2. 4 weapons, about 20 skills
3. 15-20 pets
4. Basic kill counter, titles and bounty
5. Trading and 1 leaderboard

**Open questions**

- [x] Should the top zone (Lawless Wilds) stay unsynced? Decided: only Lawless Wilds is unsynced, with a warning on entry.
- [x] Where does XP come from? Decided: a mix of quests, grinding, events and dungeons.
- [ ] What is the max level, and what happens after it? Idea: raise the cap with each update/region. Pick a launch cap.
- [x] Exact gold drop percentages and PK title buffs and nerfs: first draft in section 7, needs playtesting.
- [ ] Final studio name
- [ ] Check that "Madlands" is not already taken on Roblox
