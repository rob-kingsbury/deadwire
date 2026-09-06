# Code review #30 — findings

Fable, Session 20. Read-only pass over 2,136 lines of Lua plus the data files.
Every claim traced in code or read from the 42.20.4 jar bytecode. CONFIRMED means
traced, or shown by a checker. SUSPECTED means it looks wrong and was not proved.

## Run-mode facts established during the review

Not previously in context.md. Several findings only make sense with these.

1. A game client executes `shared/`, `client/` AND `server/` Lua. `GameWindow`
   calls `LuaManager.LoadDirBase()` for shared and client at boot;
   `GameLoadingState` calls `LoadDirBase("server")` whenever a world loads, in
   single player and multiplayer alike. So every `server/` file in this mod,
   including its event registrations, runs on multiplayer clients.
2. A dedicated server executes `shared/` and `server/` only. `GameServer` calls
   `LoadDirBase("client", true)`, and that boolean makes the loader checksum the
   files without running them. No `client/` code of ours can ever run there.
3. `sendServerCommand` is `if (GameServer.server) ...; return;`. In single player
   and on multiplayer clients it does nothing at all. The single-player loopback
   is reachable only from `SGlobalObjectNetwork`. Everything in
   `client/EventHandlers.lua` is dead in single player; the mod works there only
   because both halves share one `tileIndex` in memory.
4. `sendClientCommand` in single player goes `SinglePlayerClient.sendClientCommand`
   to a packet to `SinglePlayerServer.addIncoming` to `mainLoopDealWithNetData` to
   `OnClientCommand`. Asynchronous, next net pass, not the same frame.
5. In multiplayer `ISBuildAction:perform` returns before `create()`. The server
   rebuilds the build object in `zombie.core.BuildAction.parse`, calling
   `<Type>:new(...)` with values harvested by parameter name from the client's
   instance fields. Only String, Double, Boolean, table, InventoryItem,
   IsoDirections and IsoDeadBody survive serialization. Everything else is dropped.

## Findings, most severe first

### F1 CONFIRMED — Trip lines only work when you are standing on them
`server/ServerCommands.lua:20`, `:195-203`

The server rejects a `WireTriggered` report unless the reporting player is within
3 tiles of the wire. But the reporter is whichever client's `OnZombieUpdate` saw
the zombie, and the zombie can be anywhere loaded. A zombie crossing a tin can
line 10 tiles away: the rattle plays locally, the server drops the report with a
`debugLog` that is silent at `DEBUG=false`, the wire does not break, no cooldown
is set, camo is not degraded, and it re-fires on every crossing and every second
a zombie lingers. Reusable wires never cool down. Worse in multiplayer, where
`TriggerHandlers.lua:47` skips the local play, so nobody hears anything unless a
player is within 3 tiles.

Introduced in a12c85e (Session 17, #15) and blessed by four tests at
`tests/test_server_commands.lua:429-490`.

Fix: re-derive rather than trust distance. Accept only if an `IsoZombie` or
`IsoPlayer` is on the wire square or one of its 8 neighbours right now
(`IsoGridSquare.getMovingObjects()`; the 3x3 absorbs one tick of position lag on
a dedicated server). Keep a loose 100-tile sanity bound on the reporter as
defence in depth. Rewrite the four tests: a distant honest report with a zombie
on the tile is accepted, any report with nobody near the tile is rejected.

### F2 CONFIRMED — Every wire placement fails on a dedicated server
`server/BuildActions.lua:52-76`, `:59`, `:66`; caller `client/UI.lua:35`

`new(character, wireType)` takes an IsoPlayer first. IsoPlayer is not
serializable (fact 5) so it is dropped, and the server calls
`ISDeadwireTripLine:new("tin_can_tripline")` positionally. `character` receives
the string, `wireType` is nil, line 59 defaults every wire to tin can, and line
66 `character:getPlayerNum()` errors on a string inside `protectedCall`. The
build completes on the client, no wire appears, no kit is consumed, Lua error on
the server. Single player is unaffected because create runs locally on the
original object.

Vanilla shows the convention: `ISLightSource:new(sprite, northSprite, character)`
and `ISNaturalFloor:new(sprite, northSprite, item, character)` both put
`character` last and tolerate nil.

Fix: `ISDeadwireTripLine:new(wireType, character)`, `o.character = character`,
`o.player = character and character:getPlayerNum() or 0`, update `UI.lua:35`.
`create()` already uses `self.character`, which both paths set. Note the server
sets `item.player` to an IsoPlayer object in `parse`, so never treat
`self.player` as a number on the server.

### F3 CONFIRMED — `Events.OnPlayerConnect` does not exist
`server/WireManager.lua:257`

The string appears in none of the jar's 23,740 classes and is absent from
`LuaEventManager`'s registry. It throws "attempt to index a nil value" at load in
every run mode. Lines 255-256 already ran so `loadAll` and `reconnectSquare`
survive, but the join-time sync never fires: a client joining a server with
existing wires has an empty `WireNetwork`, so their detection ignores those
wires, their context menu never offers Remove (the exact bug the comment at
225-226 says this fixes), and CamoVisibility hides nothing.

159 tests pass because `tests/stubs.lua:10-22` auto-creates any event name on
demand. That is the checker-agrees-with-its-subject shape again.

Fix: drop `OnPlayerConnect`. Client sends `RequestWireSync` from
`Events.OnGameStart` guarded by `isClient()`; the server handler answers with the
targeted overload `sendServerCommand(player, MODULE, "WireNetworkSync", {...})`,
which does exist as `(IsoPlayer, String, String, KahluaTable)` — that settles the
"unverified 4-arg overload" note at 228-230. The client's `WireNetworkSync`
handler at `EventHandlers.lua:138-153` must also do the per-wire special-object
lookup the way `WirePlaced` does at 81-91, because chunks near spawn are already
loaded before `OnGameStart` and `LoadGridsquare` will not fire for them again.

### F4 CONFIRMED — Camouflage is not persisted and not synced
`server/WireManager.lua:137-148`, `:169-179`, `:238-246`

`saveWire` writes no camo fields, `loadAll` registers everything with
`camouflaged=false`, and the sync payload carries neither field. Every save and
reload in single player, and every server restart, strips camouflage from every
wire with no log line. Every joining client sees all camouflaged wires at full
alpha.

Fix: store `camouflaged` and `camoDurability` in the saved entry, update wherever
the flag flips (`ServerCommands.lua:244` and `:293`, `CamoDegradation.lua:74`),
restore in `loadAll`, carry both in the sync payload and apply them client-side.

### F5 CONFIRMED — `server/` code runs on multiplayer clients where it should not
Consequence of fact 1.

(a) `server/CamoDegradation.lua:41-90` runs on every multiplayer client against
that client's own copy, which never receives the trigger-degrade updates the
server applies at `ServerCommands.lua:250`. Client and server therefore expire at
different times, and when the client's copy expires first it removes the tile
from `camoTiles` without resetting alpha — that reset lives only in
`EventHandlers.lua:116-122` — leaving the wire at alpha 0 for a low-skill player
until the server's broadcast arrives. Its own `sendServerCommand` is a no-op
there. Fix: `if isClient() then return end` at the top of `onEveryTenMinutes`.

(b) `server/WireManager.lua:214-216` `loadAll` runs on multiplayer clients,
clears the empty client table and logs "loaded 0 wires". Harmless, misleading.
Guard with `isClient()`.

(c) `ServerCommands.lua:365` registers `OnClientCommand` on clients, where it
never fires. Harmless.

### F6 CONFIRMED — Broadcast-dependent client logic is dead in single player
`client/EventHandlers.lua:116-122`; comments at `ServerCommands.lua:261-266` and
`WireManager.lua:228-230`. Consequence of fact 3.

One real single-player consequence: the alpha and outline reset on uncamouflage
never runs. With `CamoVisibleToOwner=false` (not the default), a player below the
detection level sees their own camouflaged wire at alpha 0, and when the camo
expires the wire stays invisible and armed permanently.

Fix: move the alpha and outline reset into `DeadwireNetwork.setCamouflaged`
(`shared/WireNetwork.lua:163-176`) using `entry.isoObject` when present, so it
runs on whichever side flips the flag. Correct the two misleading comments.

Retracted during the review: an initial suspicion that single player played each
trigger sound twice. Fact 3 rules it out; `TriggerHandlers.lua:46` is correct.

### F7 CONFIRMED — Client authority leaks in commands the UI never uses
`server/ServerCommands.lua:75-148` `PlaceWire` trusts `args.x/y/z` with no
proximity or validity check, so a modified client can place wires on any loaded
square at any range, on blocked squares or inside another base, bounded only by
kit count and `WireMaxPerPlayer`. Nothing in the mod calls
`DeadwireClientCommands.placeWire`; the real path is the build action, which the
engine validates server-side by calling our `isValid` from `BuildAction.isValid`.
Fix: delete the handler, the wrapper at `ClientCommands.lua:11-19`, and the tests.

`:283-302` `CamouflageWire` has no owner, distance or material check, and no UI
calls `camouflageWire` either. Which means the whole camouflage feature —
CamoVisibility, CamoDegradation, twelve sandbox options — has no player-facing
entry point at all. Fix: gate on owner-or-admin plus proximity now, leave the
materials TODO for Sprint 4, and file the missing UI as its own issue.

`:154-181` `RemoveWire` enforces owner and admin but has no distance bound. Low
risk; add the same proximity bound for consistency.

### F8 CONFIRMED — Tanglefoot silently inherits a 36-second cooldown
`server/ServerCommands.lua:235` (`defaults.cooldownSeconds or 36`);
`shared/Config.lua:71-77` declares none for tanglefoot. A horde entering a
tanglefoot tile gets one 40 percent roll per tile per 36 real seconds, where the
design says 40 percent for whatever walks in. Fix: declare `cooldownSeconds`
explicitly per type (tanglefoot 0 or 1) and drop the `or 36` so a missing value
logs instead of silently defaulting.

### F9 — Settings and spec lines the code cannot honour
`shared/Config.lua:147-158` with `server/WireManager.lua:50-57`: health is set,
then `setIsThumpable(false)` removes the zombie-thump path, and nothing in the
mod ever reduces health. `Sandbox.json:73-77` promises "Zombies can thump them to
break them". SUSPECTED for player melee only — `IsoThumpable.WeaponHit` and
`Damage` exist, but whether a non-thumpable object takes weapon hits is untested.

`Config.lua:47,55,64,73` `maxSpan` and `:75` `proneDuration` are read by nothing,
so "spans up to 4/8 tiles" and "3 seconds prone" are not implemented;
`knockDown(false)` uses vanilla get-up timing. Tanglefoot's health 100 has no
degrade path, and the comment at `TriggerHandlers.lua:153` claiming the server
degrades durability is wrong — `ServerCommands` only degrades camo.
`PlayerTripDamage` and `PlayerTripStumble` are read only by the tanglefoot player
handler while their tooltips say "a wire".

Not code bugs. Tooltip and spec drift, including in PLAN.md. Fix the text to what
ships, delete the dead Config fields, or file the gaps as issues.

### F10 CONFIRMED — `FALLBACK_SPRITE` is unreachable
`shared/Config.lua:100`. `createWire` returns nil at `WireManager.lua:43-46`
before `getSprite` at 49 for any type without `WireDefaults`; all four types that
have defaults have both sprites; `BuildActions.lua:59-63` only ever receives the
four UI types. Fix: delete it, and make `getSprite` log and return nil so a
future type with no sprite fails loudly, per rule 7.

### F11 CONFIRMED — The two tiles files, and a number that means something else
`42/media/deadwire_01.tiles` is the file the game reads:
`ZomboidFileSystem.loadModTileDefs` builds `media/<name>.tiles` and calls
`IsoWorld.LoadTileDefinitions`. The string `.tiles.txt` occurs in no class.
`deadwire_01.tiles.txt` is dead to the game — but `scripts/verify_names.py:145`
reads it for sprite names and nothing reads the binary, so the file the game
actually loads is verified by nothing. Both are written from the same inputs by
pz_tilesheet, so they agree by construction, which is the same blind-checker
shape as the crafting category prefix.

Also: the third header int in the binary (0xc8 = 200) is validated by
`LoadTileDefinitions` as a tileset number in 1 to 512
(`TILESETS_PER_FILE_OTHER = 512`). It is NOT the tiledef id — that is the
mod.info number, passed separately as `fileNumber`. Vanilla `jumbo_trees.tiles`
writes 1 there. `../pz-tilesheet/README.md:123` conflates the two, so
regenerating with `--id` above 512 to dodge a collision would produce a file the
game refuses and every world sprite would vanish.

Fix: teach verify_names to parse the 120-byte binary (format at
`../pz-tilesheet/README.md:109-116`) — tileset number in 1..512, tile count at
least the highest index in `Config.Sprites` plus 1, image name equal to the pack
page name. Then delete the `.tiles.txt` from `42/media/`. Separately, in
`../pz-tilesheet`: write tileset number 1 and fix the README.

### F12 CONFIRMED — Per-tile keys accumulate in entity modData
`client/Detection.lua:82-88` stores a `dw_t_<x,y,z>` key per crossed tile in
zombie and player modData, never removes them, and they persist with the entity.
Low severity. Fix: two keys, last tile and last time.

### F13 SUSPECTED — Object reference may be missing on other clients
`client/EventHandlers.lua:81-91`, `client/CamoVisibility.lua:217-218`. The
`WirePlaced` command and the IsoThumpable object sync are separate packets. If
the command lands first, `isoObject` stays nil until chunk reload and
CamoVisibility skips the tile, so a freshly camouflaged wire is fully visible to
nearby players. Cheap mitigation: when `wire.isoObject` is nil in the
CamoVisibility loop, do the special-object lookup then.

### F14 — Hygiene
`Translate/EN/Sandbox.json` carries about thirty labels for options that do not
exist (WireMaxPerFaction, WireAffectsAnimals, WireDecay*, TinCan*BreakChance,
ReinforcedCooldownSeconds, *MaxSpan, EnableTanglefoot, TanglefootSize /
ProneSeconds / DegradePerTrigger / RainDegradeRate, CamoMaterial*,
CamoSkillRequired, CamoStepOver / Disarm*, CamoAppliesToElectric,
CamoVisibleToFaction, WireShowPlacer, MagazineSpawnRate) plus six page labels for
pages that do not exist. Harmless in-game, and a useful map of cut scope.

`Config.Sounds.ALARM_BELL`, `CAR_HORN` and `ELEC_ZAP` have no sound script, and
`EventHandlers.lua:159-167` would play the undefined `Deadwire_ElecZap` silently
when #13 lands. The ogg exists; the script block does not.

`WireNetwork.getNetworkTiles`, `getNetwork`, `ClientCommands.placeWire`,
`camouflageWire` and the debug wrappers have no callers.

`.claude/rules/development-workflow.md` still shows a `Co-Authored-By` trailer in
its commit template, against the standing order.

## WireNetwork at perimeter scale

There is no graph. Every placement mints a fresh `networkId`
(`ServerCommands.lua:123`, `:326`, `BuildActions.lua:21`), so `networks` is a 1:1
mirror of `tileIndex` with no adjacency and no walk, and `getNetworkTiles` and
`getNetwork` are uncalled.

Per zombie per tick: one key string (3 floors, 2 concats) plus one hash lookup.
O(1). The only full scans are `getPlayerTileCount`, O(N) per placement over all
wires, and the sync, O(N) per join. CamoVisibility is O(camo tiles) per second,
CamoDegradation O(camo tiles) per ten game-minutes. No recursion, no O(n^2).

For electrification you will need adjacency that does not exist yet. Compute a
circuit id per tile at place and remove time, by flood fill or union-find, never
on the zombie tick. Optional: a numeric key (`x + y*65536 + z*2^32`) to stop the
per-zombie string garbage.

## Fix plan

1. `server/ServerCommands.lua`: replace the reporter-distance gate with an
   entity-on-or-beside-the-tile check (3x3 via `getMovingObjects`), keep a
   100-tile sanity bound. Rewrite `tests/test_server_commands.lua:429-490`.
   Closes F1.
2. `server/BuildActions.lua`, `client/UI.lua:35`: `new(wireType, character)` with
   character optional. Closes F2.
3. `server/WireManager.lua`, `server/ServerCommands.lua`,
   `client/EventHandlers.lua`: remove `OnPlayerConnect`; add a client-only
   `OnGameStart` sending `RequestWireSync` and a server handler replying with the
   targeted overload; `WireNetworkSync` does the object lookup; guard
   `onInitGlobalModData` with `isClient()`. Closes F3 and F5b.
4. `server/WireManager.lua`, `shared/WireNetwork.lua`, the three flag-flip sites:
   persist and sync `camouflaged` and `camoDurability`. Closes F4.
5. `server/CamoDegradation.lua`: `isClient()` early return.
   `shared/WireNetwork.lua:163-176`: do the alpha and outline reset inside
   `setCamouflaged`, drop it from `EventHandlers.lua:116-122`, fix the two
   single-player comments. Closes F5a and F6.
6. `server/ServerCommands.lua`, `client/ClientCommands.lua`, tests: delete
   `PlaceWire` and its wrapper; gate `CamouflageWire` and `RemoveWire` on
   owner-or-admin plus proximity. File the missing camouflage UI as an issue.
   Closes F7.
7. `shared/Config.lua`, `server/ServerCommands.lua:235`: explicit
   `cooldownSeconds` per type, no `or 36`. Closes F8.
8. `shared/Config.lua:100`, `server/WireManager.lua:17-25`,
   `server/BuildActions.lua:61-63`: remove the fallback, log and return nil on a
   missing sprite. Closes F10.
9. `client/Detection.lua:82-88`: two-key dedup. `client/CamoVisibility.lua`:
   self-heal lookup when `isoObject` is nil. Closes F12 and F13.
10. `scripts/verify_names.py`: event-name check, binary `.tiles` parse, sound-name
    check. `tests/stubs.lua:10-22`: make the Events table error on unknown names
    with an allow-list generated from the same source. Then delete
    `42/media/deadwire_01.tiles.txt`. Closes F11 and the test blindness behind F3.
11. `Translate/EN/Sandbox.json`, `PLAN.md`, `shared/Config.lua`: fix the health
    tooltips, prune the orphan labels, delete `maxSpan` and `proneDuration` or
    file them, add a `Deadwire_ElecZap` sound block or note it on #13, fix the
    commit template in the rules file. Closes F9 and F14.
12. Run the three gates, sync to `C:/Users/roban/Zomboid/mods/Deadwire/`, and
    write the five run-mode facts into context.md.

## Checked and found clean

Do not re-review these next session.

`verify_names.py` 109/109, `validate_pack.py` 130/130, `run_tests.bat` 159/159
(the batch file must be run from PowerShell; `cmd //c` from Git Bash fails on
path, not on tests).

All 32 declared sandbox options have both a reader and an EN label, checked in
both directions. The only `ISBuildingObject:derive` is in `server/`, and client
files touch `ISDeadwireTripLine` only inside callbacks. Every event name except
`OnPlayerConnect` is in `LuaEventManager`.

Every Java call the mod makes is declared with matching arity in 42.20.4: the
5-arg `IsoThumpable` constructor with a nil table (vanilla precedent at
`shared/DebugCommands/DebugIsoRegionsEdit.lua:36`), `setCanPassThrough`,
`setBlockAllTheSquare`, `setIsThumpable`, `setMaxHealth`, `setHealth`, `setName`,
`transmitCompleteItemToClients`, `setAlphaAndTarget(F)`,
`setOutlineHighlight(Z)`, `setOutlineHighlightCol(FFFF)`, `AddSpecialObject`
1-arg, `transmitRemoveItemFromSquare`, `RecalcAllWithNeighbours(Z)`,
`getSpecialObjects`, `isFreeOrMidair(Z)`, `isVehicleIntersecting`,
`getFirstTypeRecurse(String)`, `getItemsFromFullType(String,Z)`,
`Remove(InventoryItem)`, `knockDown(Z)`, `isCrawling`, `isAlive`, `setBumpType`,
`setVariable(String,Z)`, `getBodyDamage`, `getBodyPart`, `AddDamage(F)`,
`PlayWorldSound` 6-arg, `WorldSoundManager.addSound` 7-arg, static
`Faction.isInSameFaction(IsoPlayer,String)`, `IsoCell.setDrag(table,int)`,
`ModData.getOrCreate`, `transmit`, `request`,
`getClimateManager():getRainIntensity`, `Role:hasCapability(Capability)`,
`getRole`, `getUsername`, `getPlayerNum`, `getMovingObjects`.

`ISContextMenu:getNew`, `addSubMenu`, `addOption` and `instanceof` are vanilla
Lua. The stumble idiom at `TriggerHandlers.lua:160-163` matches
`client/DebugUIs/DebugContextMenu.lua:1402-1405` line for line. `Base.Bell` is
vanilla (`generated/items/normal.txt:8522`), and `ItemType = base:normal` is B42
syntax with 1,099 vanilla uses.

Both mod.info copies identical; pack and tiledef resolve; id in range, no
collision. Sound scripts match `Config.Sounds` for the three shipped clips.
Translation filenames are in Translator's list and the keys match.

`WireTriggered` ignores `args.wireType` in favour of the server record.
`RemoveWire` enforces owner and admin. Debug commands are gated. `isPrivileged`
is nil-safe. Kits are checked before and consumed after placement on both paths.
The engine calls our `isValid` server-side on the build path.
`LootDistribution.lua:44` is the correct guard, and no `isServer()` remains.
Cooldowns are real seconds and broadcast as durations.

`pz-mod-checker` is a version-keyed rule engine with no notion of name
resolution, event existence, or run mode. That is why it passes this repo.

## Needs a running game

Single player: after step 1, that a zombie tripping a wire 10 to 30 tiles away
breaks it or cools it exactly once. A wire beside a door, because
`ISBuildAction:perform` calls `RecalcAllWithNeighbours(true)` right after
`create()` (`ISBuildAction.lua:230`), which makes the premise of the comment at
`WireManager.lua:68-73` false in single player and means #8 may still reproduce.
The whole `createWire` path, since Session 18 placed raw IsoObjects and an
`IsoThumpable` with `canPassThrough` has never been walked through. Whether a
non-thumpable IsoThumpable takes player weapon damage (F9). Sounds audible and
attenuating, and which of `distanceMax` 200/300 versus the `PlayWorldSound`
radius 25-60 governs. Camo alpha and rain degradation, the #25 remainder.

Dedicated server: F2 build reconstruction after the fix, F3 join sync, F4 camo
after restart, F13 packet ordering, and whether a client-side `addSound` attracts
server-simulated zombies at all in B42 multiplayer. If it does not, the server
should `addSound` when it accepts a trigger. Multiplayer cooldown mirroring
cannot be tested in single player.

## Gaps in scripts/verify_names.py

1. Event names: check every `Events\.(\w+)\.Add` against the UTF8 pool of
   `zombie/Lua/LuaEventManager`. Derived from the registry, and it would have
   caught F3. Generate `tests/stubs.lua`'s allow-list from the same source.
2. Binary `.tiles`: parse it, assert tileset number 1..512, tile count against
   `Config.Sprites`, image name against the pack page. Make `mod_sprites()` read
   the binary the game reads, not the text it ignores.
3. Sound names: `DeadwireConfig.Sounds.*` and every literal passed to
   `PlayWorldSound` must have a `sound X {}` block in `deadwire_sounds.txt` whose
   `file =` exists. Flags `Deadwire_ElecZap` today.
4. Java method existence and arity: a small receiver map (`sq` to IsoGridSquare,
   `obj` to IsoThumpable/IsoObject, `player` to IsoPlayer, `zombie` to IsoZombie,
   `inv` to ItemContainer, `getSoundManager()` to `zombie/BaseSoundManager`,
   `getWorldSoundManager()` to `zombie/WorldSoundManager`) checked with
   `pzclass.method_names()` plus descriptor arg counts. Note `BaseSoundManager`
   is at `zombie/BaseSoundManager`, not `zombie/audio/`.
5. `TRANSLATOR_BASE_NAMES` at lines 66-73 is a hardcoded set. Derive it from
   `zombie/core/Translator$1`'s pool, the same way the category prefixes were
   made to derive.
6. Optional: report `Sandbox_Deadwire_*` labels with no matching option, and mod
   functions with zero call sites.
