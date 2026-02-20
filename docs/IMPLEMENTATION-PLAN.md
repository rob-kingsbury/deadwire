# Deadwire Implementation Plan

Based on comprehensive research of the B42 Lua API, crafting system, electrical system, multiplayer architecture, and existing mod patterns. Every technical decision below is grounded in confirmed-working B42 APIs.

---

## Research Summary: What We Know Works

### Confirmed B42 APIs (BUILD ON THESE)

| Capability | API | Source |
|---|---|---|
| Zombie stagger | `zombie:setStaggerBack(true)` | IsoZombie JavaDocs, Spear Traps mod |
| Zombie knockdown/prone | `zombie:knockDown(false)` | IsoZombie JavaDocs, Spear Traps mod |
| Zombie kill | `zombie:Kill(nil)` | IsoZombie JavaDocs, Spear Traps mod |
| Zombie make crawler | `zombie:setCrawler(true)` | Customizable Zombies mod |
| Zombie speed mod | `zombie:setSpeedMod(float)` | Customizable Zombies mod |
| Tile entity detection | `OnZombieUpdate` + hash-table lookup | Spear Traps mod (proven pattern) |
| Placed destructible objects | `IsoThumpable.new()` | Vanilla barbed wire (ISBarbedWire.lua) |
| Custom buildable objects | `ISBuildingObject:derive()` | Vanilla fence/barricade system |
| Zombie-attracting sounds | `getWorldSoundManager():addSound(source, x, y, z, radius, volume)` | WorldSoundManager JavaDocs |
| Audible player sounds | `getSoundManager():PlayWorldSound(name, square, ...)` | SoundManager JavaDocs |
| Object persistent data | `obj:getModData()` | Universal PZ pattern |
| MP client->server | `sendClientCommand(module, command, args)` | PZ networking docs |
| MP server->client | `sendServerCommand(module, command, args)` | PZ networking docs |
| Power detection | `square:haveElectricity()` | IsoGenerator JavaDocs |
| Generator fuel drain | `generator:getFuel()` / `generator:setFuel()` | IsoGenerator JavaDocs |
| Server-synced config | `SandboxVars.ModName.Option` | Vanilla sandbox system |
| Client-side options | `PZAPI.ModOptions` | Native B42 system |
| Loot distribution | `ProceduralDistributions` + `OnPreDistributionMerge` | Stable since B41 |
| B42 crafting recipes | `craftRecipe` blocks with `inputs {}` / `outputs {}` | PZwiki, B42 mod examples |
| Recipe magazines | `TeachedRecipes` property on Literature items | Vanilla magazine system |

### What to AVOID (Unstable/Broken in B42)

| System | Problem | Alternative |
|---|---|---|
| Component/wiring system | Not fully implemented, blog-post vaporware | Use legacy generator radius system |
| Custom modules | Broken in multiplayer | Use `module Base` for everything |
| `OnTick` for game logic | Performance death (60x/sec * all entities) | Use `EveryOneMinute` or `EveryTenMinutes` |
| IsoZombie reference storage | Object pooling recycles instances | Always get fresh references per tick |
| Object ModData auto-sync | Unreliable for custom objects in MP | Use `sendClientCommand`/`sendServerCommand` |
| Standalone car battery API | No native support outside vehicles | Build custom DrainableComboItem abstraction |
| `DisplayName` in item scripts | Removed in 42.13 | Use translation files exclusively |
| Bare tag names | 42.13 requires namespaces | Use `deadwire:tagname` format |

---

## Architecture Overview

### Multiplayer-First Design

Everything is server-authoritative. The client requests actions, the server validates and executes, then broadcasts results.

```
CLIENT                          SERVER
  |                               |
  |-- sendClientCommand --------->|  "PlaceWire" {x, y, z, type, materials}
  |                               |  validate: player has materials? location valid?
  |                               |  execute: create IsoThumpable, consume items
  |<-- sendServerCommand ---------|  "WirePlaced" {x, y, z, wireId, networkId}
  |                               |
  |  OnZombieUpdate (detection)   |  OnZombieUpdate (detection) -- runs on both
  |                               |  server applies damage/stagger
  |<-- sendServerCommand ---------|  "WireTriggered" {wireId, soundRadius}
  |  play local sound effect      |
```

### File Structure

```
deadwire/
  Contents/mods/Deadwire/
    42/
      mod.info
      poster.png
      media/
        lua/
          shared/
            Deadwire/
              Config.lua              # Constants, wire types, tier definitions
              WireNetwork.lua         # Wire network graph logic (shared)
            Translate/EN/
              Items_EN.txt            # Item display names
              Recipes_EN.txt          # Recipe display names
              Sandbox_Deadwire_EN.txt # Sandbox option labels
          client/
            Deadwire/
              UI.lua                  # Context menus, placement UI
              BuildActions.lua        # ISBuildingObject derivatives for placement
              TimedActions.lua        # ISBaseTimedAction for crafting/wiring
              ClientCommands.lua      # sendClientCommand wrappers
              EventHandlers.lua       # OnServerCommand listener, visual/audio
              ModOptions.lua          # PZAPI.ModOptions client preferences
          server/
            Deadwire/
              ServerCommands.lua      # OnClientCommand listener, validation
              WireManager.lua         # Server-authoritative wire state
              Detection.lua           # OnZombieUpdate tile detection
              PowerManager.lua        # Electric fence power drain
              LootDistribution.lua    # ProceduralDistributions additions
        scripts/
          deadwire_items.txt          # Item definitions
          deadwire_recipes.txt        # craftRecipe definitions
        sandbox-options.txt           # SandboxVars definitions
        textures/Items/               # Item icons (placeholder PNGs)
        sound/                        # Sound effects (placeholder)
    common/
```

---

## Core Systems (Build These First)

### System 1: Wire Object Placement

The foundation everything else depends on. Wires are per-tile `IsoThumpable` objects linked via ModData.

**Pattern**: Derive from `ISBuildingObject` (same as vanilla barbed wire).

```lua
-- BuildActions.lua (client)
ISDeadwireTripLine = ISBuildingObject:derive("ISDeadwireTripLine")

function ISDeadwireTripLine:create(x, y, z, north, sprite)
    -- Client sends placement request to server
    sendClientCommand("Deadwire", "PlaceWire", {
        x = x, y = y, z = z,
        north = north,
        wireType = self.wireType,
        sprite = sprite,
    })
end
```

```lua
-- ServerCommands.lua (server)
-- Server validates and creates the IsoThumpable
local function handlePlaceWire(player, args)
    -- Validate player has materials
    -- Validate location is valid (adjacent to anchor)
    local sq = getCell():getGridSquare(args.x, args.y, args.z)
    local obj = IsoThumpable.new(getCell(), sq, args.sprite, args.north, nil)
    obj:setName("DeadwireTripLine")
    obj:setMaxHealth(50)
    obj:setHealth(50)
    obj:setCanPassThrough(true)  -- entities walk THROUGH (trigger on entry)
    obj:setIsThumpable(true)     -- zombies can destroy it

    local data = obj:getModData()
    data["dw_type"] = args.wireType
    data["dw_networkId"] = generateNetworkId()
    data["dw_active"] = true

    sq:AddSpecialObject(obj)
    obj:transmitCompleteItemToClients()
    sq:RecalcAllWithNeighbours(true)

    -- Register tile in detection system
    WireManager.registerTile(args.x, args.y, args.z, data["dw_networkId"])

    -- Consume materials from player inventory (server-side in B42)
    consumeMaterials(player, args.wireType)
end
```

**Multi-tile linking**: Each wire object stores its network ID in ModData. The `WireNetwork` (shared) module tracks which tiles belong to which network. When any tile in a network triggers, the network knows all connected tiles.

```lua
-- WireNetwork.lua (shared)
-- Hash table for O(1) tile lookup during OnZombieUpdate
local tileIndex = {}  -- key: "x,y,z" -> value: {networkId, wireType, active}

function WireNetwork.registerTile(x, y, z, networkId, wireType)
    local key = x .. "," .. y .. "," .. z
    tileIndex[key] = {
        networkId = networkId,
        wireType = wireType,
        active = true,
    }
end

function WireNetwork.getTile(x, y, z)
    return tileIndex[x .. "," .. y .. "," .. z]
end
```

### System 2: Zombie Tile Detection

The proven pattern from Spear Traps: `OnZombieUpdate` + hash-table lookup.

```lua
-- Detection.lua (server)
local function onZombieUpdate(zombie)
    if not zombie:isAlive() then return end

    local sq = zombie:getSquare()
    if not sq then return end

    local key = sq:getX() .. "," .. sq:getY() .. "," .. sq:getZ()
    local wire = WireNetwork.getTile(sq:getX(), sq:getY(), sq:getZ())
    if not wire or not wire.active then return end

    -- Prevent re-trigger: use zombie's modData (reset when zombie leaves tile)
    local zData = zombie:getModData()
    if zData["dw_triggered_" .. key] then return end
    zData["dw_triggered_" .. key] = true

    -- Dispatch to wire type handler
    if wire.wireType == "tin_can_tripline" then
        TripLineHandler.trigger(zombie, sq, wire)
    elseif wire.wireType == "reinforced_tripline" then
        ReinforcedHandler.trigger(zombie, sq, wire)
    elseif wire.wireType == "electric_fence" then
        ElectricHandler.trigger(zombie, sq, wire)
    end
end

Events.OnZombieUpdate.Add(onZombieUpdate)

-- Also detect players (for MP trip wires and self-injury)
local function onPlayerUpdate(player)
    local sq = player:getSquare()
    if not sq then return end

    local wire = WireNetwork.getTile(sq:getX(), sq:getY(), sq:getZ())
    if not wire or not wire.active then return end

    local pData = player:getModData()
    local key = sq:getX() .. "," .. sq:getY() .. "," .. sq:getZ()
    if pData["dw_triggered_" .. key] then return end
    pData["dw_triggered_" .. key] = true

    PlayerTripHandler.trigger(player, sq, wire)
end

Events.OnPlayerUpdate.Add(onPlayerUpdate)
```

**Performance note**: The hash-table lookup is O(1). Even with 10,000 zombies, each `onZombieUpdate` call does: `getSquare()` (1 Java call) -> string concat (cheap) -> table lookup (O(1)) -> early return if no wire. This is the same pattern Spear Traps uses successfully on servers.

### System 3: Sound Events

Two layers: game-world sounds (attract zombies) and audible sounds (player hears).

```lua
-- SoundSystem.lua (shared helper)
local SoundSystem = {}

function SoundSystem.makeNoise(x, y, z, radius, volume)
    -- Game-world sound: zombies hear this and investigate
    getWorldSoundManager():addSound(nil, x, y, z, radius, volume, false)
end

function SoundSystem.playEffect(square, soundName, radius)
    -- Audible sound: player hears this through speakers
    getSoundManager():PlayWorldSound(soundName, square, 0, radius, 1.0, false)
end

-- Combined: make noise AND play audible sound
function SoundSystem.triggerAlarm(x, y, z, gameRadius, soundName, audioRadius)
    SoundSystem.makeNoise(x, y, z, gameRadius, 80)
    local sq = getCell():getGridSquare(x, y, z)
    if sq then
        SoundSystem.playEffect(sq, soundName, audioRadius)
    end
end

return SoundSystem
```

---

## Phase 1: MVP (Tier 0 + Tier 1)

### Items to Define

```
-- deadwire_items.txt
module Base {

    -- Tier 0: Tin Can Trip Line (placed, not inventory)
    -- Uses existing vanilla items: EmptyTinCan, FishingLine, Twine, Nails

    -- Tier 1: Bell (new scavengeable)
    item Deadwire_Bell {
        Type = Normal,
        Weight = 0.3,
        Icon = Deadwire_Bell,
        Tags = deadwire:bell,
        WorldStaticModel = Bell_Ground,
    }
}
```

Translation file:
```
-- Items_EN.txt
Items_EN = {
    DisplayName_Deadwire_Bell = "Bell",
}
```

### Recipes to Define

```
-- deadwire_recipes.txt
module Base {

    -- Tier 0: Tin Can Trip Line
    craftRecipe Deadwire_TinCanTripLine {
        time = 120,
        tags = InHandCraft;CanBeDoneInDark,
        category = Deadwire,
        inputs {
            item 3 [Base.TinCanEmpty],
            item 1 [Base.FishingLine;Base.Twine],
            item 2 [Base.Nails],
        }
        outputs {
            item 1 Base.Deadwire_TinCanTripLineKit,
        }
    }

    -- Tier 1: Reinforced Trip Line (Carpentry 2, Trapping 2)
    craftRecipe Deadwire_ReinforcedTripLine {
        time = 200,
        tags = AnySurfaceCraft,
        category = Deadwire,
        SkillRequired = Carpentry:2;Trapping:2,
        xpAward = Carpentry:15;Trapping:15,
        inputs {
            item 1 [Base.Wire],
            item 3 [Base.TinCanEmpty;Base.Deadwire_Bell],
            item 2 [Base.Nails],
            item 1 [Base.Hammer] mode:keep flags[MayDegradeLight],
        }
        outputs {
            item 1 Base.Deadwire_ReinforcedTripLineKit,
        }
    }

    -- Tier 1: Reinforced Trip Line with Bell
    craftRecipe Deadwire_BellTripLine {
        time = 200,
        tags = AnySurfaceCraft,
        category = Deadwire,
        SkillRequired = Carpentry:2;Trapping:2,
        xpAward = Carpentry:15;Trapping:15,
        inputs {
            item 1 [Base.Wire],
            item 1 [Base.Deadwire_Bell],
            item 2 [Base.Nails],
            item 1 [Base.Hammer] mode:keep flags[MayDegradeLight],
        }
        outputs {
            item 1 Base.Deadwire_BellTripLineKit,
        }
    }
}
```

### Loot Distribution

```lua
-- LootDistribution.lua (server)
local function preDistributionMerge()
    local distributions = {
        -- Bells: churches, schools, farms, reception areas
        ChurchMisc        = { { item = "Base.Deadwire_Bell", chance = 12 } },
        SchoolLockers      = { { item = "Base.Deadwire_Bell", chance = 4 } },
        FarmingTools       = { { item = "Base.Deadwire_Bell", chance = 8 } },
        BarnTools          = { { item = "Base.Deadwire_Bell", chance = 10 } },
        OfficeDesk         = { { item = "Base.Deadwire_Bell", chance = 2 } },
    }

    for distName, items in pairs(distributions) do
        if ProceduralDistributions.list[distName] then
            for _, entry in ipairs(items) do
                table.insert(ProceduralDistributions.list[distName].items, entry.item)
                table.insert(ProceduralDistributions.list[distName].items, entry.chance)
            end
        end
    end
end

Events.OnPreDistributionMerge.Add(preDistributionMerge)
```

### SandboxVars (Phase 1)

```
-- sandbox-options.txt
option Deadwire.TinCanSoundRadius {
    type = integer, default = 25, min = 5, max = 100,
    page = Deadwire, translation = Deadwire_TinCanSoundRadius,
}
option Deadwire.BellSoundRadius {
    type = integer, default = 60, min = 10, max = 150,
    page = Deadwire, translation = Deadwire_BellSoundRadius,
}
option Deadwire.ReinforcedSoundRadius {
    type = integer, default = 40, min = 10, max = 100,
    page = Deadwire, translation = Deadwire_ReinforcedSoundRadius,
}
option Deadwire.TinCanBreakOnTrigger {
    type = boolean, default = true,
    page = Deadwire, translation = Deadwire_TinCanBreakOnTrigger,
}
option Deadwire.TwineBreakChance {
    type = integer, default = 80, min = 0, max = 100,
    page = Deadwire, translation = Deadwire_TwineBreakChance,
}
```

### Wire Type Handlers (Phase 1)

```lua
-- handlers/TripLineHandler.lua (server)
local TripLineHandler = {}

function TripLineHandler.trigger(zombie, sq, wire)
    local x, y, z = sq:getX(), sq:getY(), sq:getZ()
    local radius = SandboxVars.Deadwire.TinCanSoundRadius or 25

    -- Make noise (attracts zombies)
    getWorldSoundManager():addSound(nil, x, y, z, radius, 60, false)

    -- Broadcast to clients for audible sound effect
    sendServerCommand("Deadwire", "WireTriggered", {
        x = x, y = y, z = z,
        soundName = "Deadwire_TinCanRattle",
        audioRadius = 15,
    })

    -- Tin can lines break on trigger (configurable)
    if SandboxVars.Deadwire.TinCanBreakOnTrigger then
        WireManager.destroyWire(x, y, z)
    end
end

-- handlers/ReinforcedHandler.lua (server)
local ReinforcedHandler = {}

function ReinforcedHandler.trigger(zombie, sq, wire)
    local x, y, z = sq:getX(), sq:getY(), sq:getZ()

    -- Determine sound based on noisemaker type
    local hasBell = wire.hasBell
    local radius = hasBell
        and (SandboxVars.Deadwire.BellSoundRadius or 60)
        or (SandboxVars.Deadwire.ReinforcedSoundRadius or 40)
    local soundName = hasBell and "Deadwire_BellRing" or "Deadwire_WireRattle"

    -- Make noise
    getWorldSoundManager():addSound(nil, x, y, z, radius, 80, false)

    -- Broadcast sound
    sendServerCommand("Deadwire", "WireTriggered", {
        x = x, y = y, z = z,
        soundName = soundName,
        audioRadius = radius / 2,
    })

    -- Reinforced wires DON'T break (but have cooldown)
    wire.cooldownUntil = getGameTime():getWorldAgeHours() + 0.01  -- ~36 seconds
end

return ReinforcedHandler
```

### Client Event Handler (Phase 1)

```lua
-- EventHandlers.lua (client)
local function onServerCommand(module, command, args)
    if module ~= "Deadwire" then return end

    if command == "WireTriggered" then
        local sq = getCell():getGridSquare(args.x, args.y, args.z)
        if sq then
            getSoundManager():PlayWorldSound(args.soundName, sq, 0, args.audioRadius, 1.0, false)
        end
    elseif command == "WirePlaced" then
        -- Update local wire network cache
        WireNetwork.registerTile(args.x, args.y, args.z, args.networkId, args.wireType)
    elseif command == "WireDestroyed" then
        WireNetwork.unregisterTile(args.x, args.y, args.z)
    end
end

Events.OnServerCommand.Add(onServerCommand)
```

### Phase 1 Deliverables

| File | Purpose | Est. Lines |
|---|---|---|
| `shared/Deadwire/Config.lua` | Constants, wire type definitions | ~80 |
| `shared/Deadwire/WireNetwork.lua` | Wire network hash-table, tile registration | ~120 |
| `client/Deadwire/UI.lua` | Right-click context menu for placement | ~150 |
| `client/Deadwire/BuildActions.lua` | ISBuildingObject derivatives | ~200 |
| `client/Deadwire/TimedActions.lua` | Placement timed actions | ~100 |
| `client/Deadwire/ClientCommands.lua` | sendClientCommand wrappers | ~50 |
| `client/Deadwire/EventHandlers.lua` | OnServerCommand listener | ~80 |
| `client/Deadwire/ModOptions.lua` | Client preferences | ~60 |
| `server/Deadwire/ServerCommands.lua` | OnClientCommand handler | ~200 |
| `server/Deadwire/WireManager.lua` | Server-authoritative wire state | ~150 |
| `server/Deadwire/Detection.lua` | OnZombieUpdate + OnPlayerUpdate detection | ~100 |
| `server/Deadwire/LootDistribution.lua` | Bell spawn tables | ~40 |
| `server/Deadwire/handlers/TripLineHandler.lua` | Tin can trigger logic | ~50 |
| `server/Deadwire/handlers/ReinforcedHandler.lua` | Wire+bell trigger logic | ~60 |
| `scripts/deadwire_items.txt` | Item definitions | ~30 |
| `scripts/deadwire_recipes.txt` | craftRecipe definitions | ~60 |
| `sandbox-options.txt` | SandboxVars | ~30 |
| `shared/Translate/EN/*.txt` | Translation files (3) | ~40 |
| **Total** | | **~1,600** |

### Phase 1 Test Plan

1. **Placement**: Craft tin can trip line, place between two fence posts. Verify IsoThumpable appears on each tile.
2. **Trigger**: Lure zombie into trip line. Verify sound event fires, zombie attracts, wire breaks.
3. **Reinforced**: Place reinforced wire. Verify it survives trigger, resets cooldown.
4. **Bell**: Find/spawn bell. Craft bell trip line. Verify louder sound radius.
5. **MP sync**: Two players. Player A places wire. Player B sees it. Zombie triggers it. Both players hear sound.
6. **Destruction**: Zombie horde attacks wire. Verify IsoThumpable health decrements and wire breaks.
7. **SandboxVars**: Change sound radius in server settings. Verify new values apply.

---

## Phase 2: Pull-Alarm System (Tier 2)

### New Concept: Mechanical Wire Routing

The pull-alarm connects a trip wire at the perimeter to a bell/horn mounted at the base. This is a **logical link**, not a physical wire rendered on every tile. The connection is stored in ModData as coordinate pairs.

```lua
-- Alarm network: trip trigger at (100,200,0) connected to bell at (50,150,1)
-- Stored on the trip trigger object:
data["dw_alarm_target_x"] = 50
data["dw_alarm_target_y"] = 150
data["dw_alarm_target_z"] = 1

-- When triggered, server looks up target and fires sound there
function PullAlarmHandler.trigger(zombie, sq, wire)
    local data = wire.modData
    local targetX = data["dw_alarm_target_x"]
    local targetY = data["dw_alarm_target_y"]
    local targetZ = data["dw_alarm_target_z"]

    -- Sound at the BELL location, not the trip wire
    local bellRadius = SandboxVars.Deadwire.AlarmBellRadius or 50
    getWorldSoundManager():addSound(nil, targetX, targetY, targetZ, bellRadius, 90, false)

    sendServerCommand("Deadwire", "AlarmTriggered", {
        triggerX = sq:getX(), triggerY = sq:getY(), triggerZ = sq:getZ(),
        bellX = targetX, bellY = targetY, bellZ = targetZ,
        soundName = wire.hasCHorn and "Deadwire_CarHorn" or "Deadwire_AlarmBell",
        audioRadius = wire.hasCarHorn and 80 or 40,
    })
end
```

### New Items (Phase 2)

| Item | Type | Source |
|---|---|---|
| `Deadwire_PullAlarmTrigger` | Normal (craftable) | Wire + Spring + 2x Nails + Screwdriver |
| `Deadwire_AlarmBellMount` | Normal (craftable) | Bell + Nails + Plank + Hammer |
| `Deadwire_AlarmHornMount` | Normal (craftable) | CarHorn + ElecWire + Nails + Screwdriver |
| `Deadwire_CarHorn` | Normal (salvaged) | Vehicles (Mechanics 2) |
| `Deadwire_Spring` | Normal (salvaged) | Mattresses, appliances, clocks |
| `Deadwire_SecurityHandbook` | Literature | Magazine: teaches pull-alarm recipes |

### Wiring Action (Tier 2 Unique Mechanic)

Player crafts the trigger and mount, then "connects" them. This is a **timed action** that requires Electric Wire in inventory and Electrical 3.

```lua
-- Client: player right-clicks alarm trigger, selects "Connect to Bell Mount"
-- Then clicks on the bell mount location
-- Client sends: sendClientCommand("Deadwire", "ConnectAlarm", {
--     triggerX, triggerY, triggerZ,
--     bellX, bellY, bellZ,
--     wireCount = distance  -- 1 ElecWire per N tiles
-- })
-- Server validates distance, materials, skill level, then stores link in ModData
```

### Phase 2 Additional Files

| File | Purpose | Est. Lines |
|---|---|---|
| `server/Deadwire/handlers/PullAlarmHandler.lua` | Pull-alarm trigger logic | ~80 |
| `client/Deadwire/WiringAction.lua` | Two-click wiring UI (trigger -> bell) | ~150 |
| `server/Deadwire/VehicleSalvage.lua` | Car horn salvage via OnVehicleDamaged | ~50 |
| Updated `deadwire_items.txt` | +6 items | ~60 |
| Updated `deadwire_recipes.txt` | +4 recipes | ~80 |
| Updated `LootDistribution.lua` | Magazine + spring spawn tables | ~30 |
| **Phase 2 addition** | | **~450** |

---

## Phase 3: Electric Livestock Fencing (Tier 3)

### Power System Design

Uses the **legacy generator radius system** (confirmed stable). The electric fence checks `square:haveElectricity()` and drains generator fuel via `generator:setFuel()`.

**Critical decision**: Car batteries as standalone power require a **custom abstraction** since PZ has no native API for this outside vehicles. Implementation:

```lua
-- PowerManager.lua (server)
-- Runs on EveryTenMinutes (performance-safe)

local PowerManager = {}
PowerManager.fenceNetworks = {}  -- networkId -> { tiles, powerSource, drain }

function PowerManager.onTenMinutes()
    for networkId, network in pairs(PowerManager.fenceNetworks) do
        if network.powerType == "generator" then
            PowerManager.drainGenerator(network)
        elseif network.powerType == "battery" then
            PowerManager.drainBattery(network)
        end
    end
end

function PowerManager.drainGenerator(network)
    local gen = PowerManager.findGenerator(network.chargerX, network.chargerY, network.chargerZ)
    if not gen or not gen:isActivated() then
        network.powered = false
        return
    end

    local drain = network.currentDrain * (10 / 60)  -- 10 min fraction of hourly rate
    local fuel = gen:getFuel()
    if fuel <= 0 then
        network.powered = false
        return
    end

    gen:setFuel(math.max(0, fuel - drain))
    network.powered = true
end

function PowerManager.drainBattery(network)
    -- Custom battery: DrainableComboItem tracked in charger's ModData
    local sq = getCell():getGridSquare(network.chargerX, network.chargerY, network.chargerZ)
    if not sq then network.powered = false; return end

    local charger = PowerManager.findChargerOnSquare(sq)
    if not charger then network.powered = false; return end

    local data = charger:getModData()
    local charge = data["dw_battery_charge"] or 0
    if charge <= 0 then
        network.powered = false
        return
    end

    local drain = network.currentDrain * (10 / 60)
    data["dw_battery_charge"] = math.max(0, charge - drain)
    charger:transmitModData()
    network.powered = charge > drain
end

-- Zombie contact: called from Detection.lua when zombie hits electrified tile
function PowerManager.onZombieContact(networkId)
    local network = PowerManager.fenceNetworks[networkId]
    if not network or not network.powered then return false end

    -- Each contact adds to drain rate
    network.currentDrain = network.currentDrain + (SandboxVars.Deadwire.PowerDrainPerHit or 0.2)

    -- Drain decays over time (reset each EveryTenMinutes cycle)
    -- This creates the "sustained contact = faster drain" mechanic
    return true  -- fence is powered, apply stagger
end

Events.EveryTenMinutes.Add(PowerManager.onTenMinutes)
```

### Electric Fence Handler

```lua
-- handlers/ElectricHandler.lua (server)
local ElectricHandler = {}

function ElectricHandler.trigger(zombie, sq, wire)
    -- Check if fence is powered
    local isPowered = PowerManager.onZombieContact(wire.networkId)
    if not isPowered then return end  -- Dead fence = no effect

    -- Stagger zombie (confirmed working API)
    zombie:setStaggerBack(true)

    -- Zap sound at contact point
    local x, y, z = sq:getX(), sq:getY(), sq:getZ()
    local zapRadius = SandboxVars.Deadwire.ElectricZapRadius or 30
    getWorldSoundManager():addSound(nil, x, y, z, zapRadius, 50, false)

    sendServerCommand("Deadwire", "ElectricZap", {
        x = x, y = y, z = z,
        soundName = "Deadwire_ElecZap",
        audioRadius = 15,
    })

    -- Cooldown per zombie (stagger duration)
    local staggerDuration = SandboxVars.Deadwire.FenceStaggerDuration or 1.5
    -- Wire cooldown prevents instant re-trigger for this zombie
    wire.cooldownUntil = getGameTime():getWorldAgeHours() + (staggerDuration / 3600)
end

return ElectricHandler
```

### New Items (Phase 3)

| Item | Type | Source |
|---|---|---|
| `Deadwire_FenceCharger` | Normal (scavenge only) | Barns, farm supply, hardware stores |
| `Deadwire_Insulator` | Normal (scavenge or craft) | Same locations, or Pottery 2 |
| `Deadwire_GroundRod` | Normal (craftable) | Iron Pipe + Wire + Hammer |
| `Deadwire_FarmManual` | Literature | Magazine: teaches electric fence recipes |

### Crafting Chain (Phase 3)

| Step | Recipe | Requirements |
|---|---|---|
| 1. Ground Rod | Iron Pipe + Wire + Hammer | Electrical 3 |
| 2. Insulator | Clay (pottery workbench) | Pottery 2, KilnCraft |
| 3. Insulated Fence Post | Wooden Post + Insulator + Hammer | Carpentry 3 |
| 4. Insulated Fence Wire | Wire/Barbed Wire on insulated posts | Electrical 5, needToBeLearn (magazine) |
| 5. Charger Connection | ElecWire from charger to fence + ground rod | Electrical 5 |
| 6. Battery Hookup | Charger adjacent to car battery item | Electrical 3 |
| 7. Generator Hookup | Charger within generator range + connected | Electrical 5 |

### Phase 3 Additional Files

| File | Purpose | Est. Lines |
|---|---|---|
| `server/Deadwire/PowerManager.lua` | Power drain, battery abstraction | ~250 |
| `server/Deadwire/handlers/ElectricHandler.lua` | Electric stagger logic | ~80 |
| `client/Deadwire/ChargerUI.lua` | Charger placement + connection UI | ~150 |
| `client/Deadwire/PowerOverlay.lua` | Visual indicator for powered/unpowered | ~100 |
| Updated item/recipe scripts | +4 items, +5 recipes | ~120 |
| Updated loot distribution | Charger, insulator, magazine spawns | ~40 |
| Updated sandbox-options | Power drain, stagger duration, etc. | ~30 |
| **Phase 3 addition** | | **~770** |

---

## Phase 4: Advanced Applications (Tier 4)

### Modified Fence Charger

Engineer right-clicks charger -> "Remove Safety Limiters" (requires screwdriver).

```lua
-- Changes charger ModData:
data["dw_modified"] = true
data["dw_kill_chance"] = SandboxVars.Deadwire.ModifiedKillChance or 15
data["dw_drain_multiplier"] = 3.5
data["dw_burnout_chance"] = 2  -- % per trigger cycle
```

Modified handler adds to `ElectricHandler.trigger()`:
```lua
if wire.isModified then
    local killRoll = ZombRand(100)
    if killRoll < wire.killChance then
        zombie:Kill(nil)
    end
    -- Burnout check
    local burnoutRoll = ZombRand(100)
    if burnoutRoll < wire.burnoutChance then
        PowerManager.destroyCharger(wire.networkId)
    end
end
```

### Trip Line Detonation

Connects reinforced trip line to vanilla noisemaker or pipe bomb. When triggered, activates the explosive.

```lua
-- Conceptual: trigger sets off the linked explosive item
-- This requires finding the explosive IsoObject on the linked tile
-- and calling its activation method (needs B42 API verification for explosives)
```

### Electrified Barbed Wire

When barbed wire fence is also part of an electric network:
- `zombie:setCrawler(true)` on prolonged contact (tangle)
- Body part damage via `zombie:getBodyDamage():getBodyPart(BodyPartType.X):AddDamage(amount)`

### Phase 4 Additional Files

| File | Purpose | Est. Lines |
|---|---|---|
| `server/Deadwire/handlers/ModifiedChargerHandler.lua` | Kill chance, burnout | ~60 |
| `server/Deadwire/handlers/DetonationHandler.lua` | Explosive trigger link | ~80 |
| `server/Deadwire/handlers/ElecBarbedWireHandler.lua` | Scratch + tangle | ~70 |
| `client/Deadwire/ModifyChargerAction.lua` | Engineer right-click action | ~50 |
| Updated sandbox-options | Kill chance, fire risk, etc. | ~20 |
| **Phase 4 addition** | | **~280** |

---

## Cumulative Scope

| Phase | New Lines | Cumulative | Shippable? |
|---|---|---|---|
| Phase 1 (MVP) | ~1,600 | ~1,600 | Yes - Workshop release |
| Phase 2 (Pull-Alarms) | ~450 | ~2,050 | Yes - Workshop update |
| Phase 3 (Electric) | ~770 | ~2,820 | Yes - Workshop update |
| Phase 4 (Advanced) | ~280 | ~3,100 | Yes - Workshop update |

These estimates exclude sprites, sounds, and poster art.

---

## Development Order (What to Build First)

### Sprint 1: Foundation (required for everything)

1. **Mod scaffolding**: `mod.info`, directory structure, `Config.lua`
2. **WireNetwork.lua**: Hash-table tile index (shared)
3. **Detection.lua**: `OnZombieUpdate` + `OnPlayerUpdate` with hash-table lookup
4. **ServerCommands.lua**: `OnClientCommand` dispatcher
5. **EventHandlers.lua**: `OnServerCommand` listener for clients

**Test**: Hardcode a wire tile at a known location. Walk a zombie into it. Verify detection fires. This proves the core mechanic works before building any UI or crafting.

### Sprint 2: Placement System

6. **BuildActions.lua**: `ISBuildingObject` derivative for wire placement
7. **UI.lua**: Right-click context menu
8. **TimedActions.lua**: Placement timed action
9. **WireManager.lua**: Server-side wire creation/destruction

**Test**: Craft and place a tin can trip line via context menu. Verify it appears in the world, syncs to other players, and can be destroyed.

### Sprint 3: Sound + Trigger + Polish

10. **TripLineHandler.lua**: Sound events on trigger, wire break
11. **ReinforcedHandler.lua**: Reusable wire with cooldown
12. **LootDistribution.lua**: Bell spawns
13. **Item/recipe scripts**: All Phase 1 items and recipes
14. **SandboxVars**: All Phase 1 configuration
15. **ModOptions.lua**: Client preferences

**Test**: Full Phase 1 test plan (see above). Ship to Workshop.

### Sprint 4-6: Phases 2-4

Follow the phase order. Each phase is an independent Workshop update.

---

## Key Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| B42 patch breaks mod | High | Medium | Pin to B42 version, test on each patch |
| `OnZombieUpdate` performance with many wires | Low | High | Hash-table is O(1); benchmark with 1000+ zombies |
| `setStaggerBack` doesn't look right visually | Medium | Medium | Test in-game; fallback to `knockDown` if needed |
| Battery standalone power too complex | Medium | Low | Phase 3 only; can ship Phases 1-2 without it |
| Sprites/sounds delay release | Medium | Low | Use placeholder vanilla sprites initially |
| MP desync on wire state | Medium | High | Server-authoritative; broadcast all state changes |
| 42.13 registry changes break item tags | Low | Medium | Use `deadwire:tagname` namespace from day one |

---

## Reference Materials

### Essential Reading Before Coding

- [Spear Traps source](https://github.com/quarantin/zomboid-spear-traps) -- detection pattern
- [Vanilla ISBarbedWire.lua](https://github.com/Project-Zomboid-Community-Modding/ProjectZomboid-Vanilla-Lua) -- placement pattern
- [Konijima PZ-BaseMod](https://github.com/Konijima/PZ-BaseMod) -- MP command pattern
- [Immersive Solar Arrays](https://github.com/radx5Blue/ImmersiveSolarArrays) -- custom power system
- [PZEventDoc](https://github.com/demiurgeQuantified/PZEventDoc/blob/develop/docs/Events.md) -- complete event list
- [IsoZombie JavaDocs](https://projectzomboid.com/modding/zombie/characters/IsoZombie.html)
- [IsoThumpable JavaDocs](https://projectzomboid.com/modding/zombie/iso/objects/IsoThumpable.html)
- [WorldSoundManager JavaDocs](https://projectzomboid.com/modding/zombie/WorldSoundManager.html)
- [PZwiki: CraftRecipe](https://pzwiki.net/wiki/CraftRecipe) -- B42 recipe format
- [B42 Mod Template](https://github.com/LabX1/ProjectZomboid-Build42-ModTemplate) -- folder structure
- [Modding Migration Guide 42.13](https://theindiestone.com/forums/index.php?/topic/88499-modding-migration-guide-4213/)
