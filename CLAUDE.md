# Madlands (Roblox RPG)

Roblox RPG written in Luau, synced into Studio with Rojo. Read DESIGN.md before designing or building anything.

## Rules
- The server decides all combat, damage, loot, trading and PK rules. Never trust the client.
- Weapons, skills, pets and zones live in config tables, not hard-coded.
- Save player data only with ProfileStore. Do not write custom DataStore saving.
- Build one feature at a time. Do not touch unrelated systems.
- Explain what you changed in simple words, and tell me how to test it in Studio.
- Keep every RemoteEvent validated on the server (check player, cooldown, range, ownership).

## Project layout
- `src/server`: server scripts (combat, data, trading, PK rules)
- `src/shared`: shared modules and config tables
- `src/client`: UI, input, camera
- `default.project.json`: Rojo project file

## Workflow
- I run `.\rojo.exe serve` and connect from Roblox Studio, then press Play to test.
- I paste Output errors back to you to fix.
- Commit after each working step.

## Build order
1. Player data (ProfileStore)
2. One weapon and basic server-side combat
3. A mob with aggro, loot and XP
4. Skills (4 per weapon, hotkeys, cooldowns)
5. Second weapon and swap, per-weapon mastery
6. Zone system: level sync and gear scaling
7. City, gate and TeleportService between places
8. PvP, gold drop, kill counter, titles
9. Pets
10. Trading and shops
