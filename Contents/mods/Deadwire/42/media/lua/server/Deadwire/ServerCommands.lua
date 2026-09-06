-- Deadwire ServerCommands: OnClientCommand dispatcher
-- Server: validates client requests and executes authoritative actions
--
-- All game-state mutations happen here. Clients request via sendClientCommand,
-- server validates, executes, and broadcasts results via sendServerCommand.

require "Deadwire/Config"
require "Deadwire/WireNetwork"
require "Deadwire/WireManager"

DeadwireServerCommands = DeadwireServerCommands or {}

-- Command handler table
local handlers = {}

-- A WireTriggered report is a claim, not an observation. Detection has to run
-- client-side (OnZombieUpdate is a client event), so any client can send this
-- for any coordinates and the server must re-derive the fact for itself: is
-- something actually standing on that wire right now.
--
-- What this replaces is #31. The old gate measured how far away the REPORTING
-- player was, but the reporter is whichever client's OnZombieUpdate saw the
-- zombie, and the zombie can be anywhere loaded. Trip lines therefore only
-- fired when a player was already within 3 tiles of them, which is the mod's
-- core feature not working.
--
-- 3x3 rather than the single tile: on a dedicated server the report is a tick
-- or two behind where the entity has since moved to.
local TRIGGER_SCAN_RADIUS = 1

-- Loose bound on the reporter, defence in depth only. Nothing legitimate
-- reports a wire on the far side of the loaded map. This is deliberately NOT
-- a proximity check -- proximity is what was wrong before.
local TRIGGER_SANITY_DIST = 100

-- Is a zombie or a player on the wire square or one of its 8 neighbours?
-- IsoGridSquare.getMovingObjects() is the live list, so this is the server's
-- own reading of world state rather than the client's word for it.
local function triggeringEntityNear(x, y, z)
    local cell = getCell()
    if not cell then return false end

    for dx = -TRIGGER_SCAN_RADIUS, TRIGGER_SCAN_RADIUS do
        for dy = -TRIGGER_SCAN_RADIUS, TRIGGER_SCAN_RADIUS do
            local sq = cell:getGridSquare(x + dx, y + dy, z)
            local movers = sq and sq:getMovingObjects()
            if movers then
                for i = 0, movers:size() - 1 do
                    local o = movers:get(i)
                    if o and (instanceof(o, "IsoZombie") or instanceof(o, "IsoPlayer")) then
                        return true
                    end
                end
            end
        end
    end
    return false
end

-- DRY: validate args contain position fields
local function hasPosition(args)
    return args and args.x and args.y and args.z
end

-- Admin/privileged check.
-- Capability.CanBuildAnywhere does not exist in 42.20; indexing the enum
-- yielded nil, hasCapability(nil) returned false, and admins were silently
-- denied. The real capability is UseBuildCheat. getRole() can also return nil
-- (single player, or a player with no role assigned), which threw. Fixes #14.
local function isPrivileged(player)
    if not player then return false end
    local role = player:getRole()
    if not role then return false end
    return role:hasCapability(Capability.UseBuildCheat)
end

-- Does this player actually hold the kit this wire type costs?
-- The client-side build action consumes a kit, but PlaceWire is a separate
-- server command any client can send directly, so it must check for itself.
local function findKit(player, wireType)
    local kitItem = DeadwireConfig.KitItems[wireType]
    if not kitItem then return nil, true end   -- type needs no kit
    local inv = player:getInventory()
    if not inv then return nil, false end
    return inv:getFirstTypeRecurse(kitItem), false
end

-----------------------------------------------------------
-- Main Dispatcher
-----------------------------------------------------------

local function onClientCommand(module, command, player, args)
    if module ~= DeadwireConfig.MODULE then return end

    if not DeadwireConfig.getSandbox("EnableMod", true) then
        DeadwireConfig.debugLog("Mod disabled, ignoring: " .. command)
        return
    end

    local handler = handlers[command]
    if handler then
        DeadwireConfig.debugLog("Command: " .. command .. " from " .. (player:getUsername() or "SP"))
        handler(player, args)
    else
        DeadwireConfig.log("Unknown command: " .. command)
    end
end

-----------------------------------------------------------
-- PlaceWire: Client requests wire placement at a tile
-----------------------------------------------------------

handlers["PlaceWire"] = function(player, args)
    if not hasPosition(args) or not args.wireType then
        DeadwireConfig.log("PlaceWire: invalid args")
        return
    end

    local wireType = args.wireType
    local defaults = DeadwireConfig.WireDefaults[wireType]
    if not defaults then
        DeadwireConfig.log("PlaceWire: unknown type " .. tostring(wireType))
        return
    end

    if not DeadwireConfig.isTierEnabled(defaults.tier) then
        DeadwireConfig.debugLog("PlaceWire: tier " .. defaults.tier .. " disabled")
        return
    end

    -- Wire limit per player
    local username = player:getUsername() or "SP"
    local maxWires = DeadwireConfig.getSandbox("WireMaxPerPlayer", 50)
    if DeadwireNetwork.getPlayerTileCount(username) >= maxWires then
        DeadwireConfig.log("PlaceWire: " .. username .. " at limit (" .. maxWires .. ")")
        return
    end

    -- Validate square
    local sq = getCell():getGridSquare(args.x, args.y, args.z)
    if not sq then
        DeadwireConfig.log("PlaceWire: no square at " .. args.x .. "," .. args.y .. "," .. args.z)
        return
    end

    -- No stacking wires on same tile
    if DeadwireNetwork.getTile(args.x, args.y, args.z) then
        DeadwireConfig.log("PlaceWire: tile occupied")
        return
    end

    -- Player must actually hold the kit. Without this a modified client can
    -- place wires it never crafted, bounded only by WireMaxPerPlayer. Fixes #15.
    local kitItemObj, kitless = findKit(player, wireType)
    if not kitless and not kitItemObj then
        DeadwireConfig.log("PlaceWire: " .. username .. " has no kit for " .. wireType)
        return
    end

    -- Create IsoThumpable + register in WireNetwork + persist
    local networkId = DeadwireNetwork.generateNetworkId()
    local obj = DeadwireWireManager.createWire(sq, wireType, username, networkId, args.north)
    if not obj then
        DeadwireConfig.log("PlaceWire: WireManager.createWire failed")
        return
    end

    -- Consume only after placement is confirmed
    if kitItemObj then
        player:getInventory():Remove(kitItemObj)
    end

    if DeadwireConfig.getSandbox("LogWirePlacements", true) then
        DeadwireConfig.log("Wire placed: " .. wireType .. " at "
            .. args.x .. "," .. args.y .. "," .. args.z .. " by " .. username)
    end

    sendServerCommand(DeadwireConfig.MODULE, "WirePlaced", {
        x = args.x,
        y = args.y,
        z = args.z,
        networkId = networkId,
        wireType = wireType,
        ownerId = username,
    })
end

-----------------------------------------------------------
-- RemoveWire: Client requests wire removal
-----------------------------------------------------------

handlers["RemoveWire"] = function(player, args)
    if not hasPosition(args) then
        DeadwireConfig.log("RemoveWire: invalid args")
        return
    end

    local wire = DeadwireNetwork.getTile(args.x, args.y, args.z)
    if not wire then
        DeadwireConfig.debugLog("RemoveWire: no wire at " .. args.x .. "," .. args.y .. "," .. args.z)
        return
    end

    -- Only owner or admin can remove
    local username = player:getUsername() or "SP"
    if wire.ownerId ~= username and not isPrivileged(player) then
        DeadwireConfig.log("RemoveWire: " .. username .. " not authorized")
        return
    end

    -- Destroy IsoThumpable + unregister + remove from save
    DeadwireWireManager.destroyWire(args.x, args.y, args.z)

    sendServerCommand(DeadwireConfig.MODULE, "WireDestroyed", {
        x = args.x,
        y = args.y,
        z = args.z,
    })
end

-----------------------------------------------------------
-- WireTriggered: Client reports a wire was triggered
-- Server processes state changes (break, cooldown, camo degrade)
-- and broadcasts to all clients for MP sound.
-----------------------------------------------------------

handlers["WireTriggered"] = function(player, args)
    if not hasPosition(args) or not args.wireType then return end

    -- Sanity bound on the reporter first, because it is one comparison and
    -- rules out a client reporting coordinates it has no business knowing.
    -- Floor is not checked here: a player on any floor can see a zombie on
    -- another, and the wire's own floor is checked below.
    local psq = player:getSquare()
    if not psq
        or math.abs(psq:getX() - args.x) > TRIGGER_SANITY_DIST
        or math.abs(psq:getY() - args.y) > TRIGGER_SANITY_DIST then
        DeadwireConfig.debugLog("WireTriggered: rejected out-of-range report from "
            .. (player:getUsername() or "SP"))
        return
    end

    local wire = DeadwireNetwork.getTile(args.x, args.y, args.z)
    if not wire then return end

    -- The real gate: something has to actually be there. Costs 9 square
    -- lookups and only runs once a wire is known to exist at those coords.
    if not triggeringEntityNear(args.x, args.y, args.z) then
        DeadwireConfig.debugLog("WireTriggered: nothing on or beside "
            .. args.x .. "," .. args.y .. "," .. args.z .. ", report ignored")
        return
    end

    local wireType = wire.wireType
    local defaults = DeadwireConfig.WireDefaults[wireType]
    if not defaults then return end

    -- Determine sound info for broadcast
    local soundMap = {
        tin_can_tripline    = DeadwireConfig.Sounds.TIN_CAN_RATTLE,
        reinforced_tripline = DeadwireConfig.Sounds.WIRE_RATTLE,
        bell_tripline       = DeadwireConfig.Sounds.BELL_RING,
    }
    local soundName = soundMap[wireType]
    local soundRadius = defaults.soundRadius or 25
    local multiplier = DeadwireConfig.getSandbox("SoundMultiplier", 1.0)
    soundRadius = math.floor(soundRadius * multiplier)

    -- State changes based on wire type
    local cooldownSeconds = nil
    if DeadwireConfig.breaksOnTrigger(wireType) then
        -- Single-use: destroy wire
        DeadwireWireManager.destroyWire(args.x, args.y, args.z)
        sendServerCommand(DeadwireConfig.MODULE, "WireDestroyed", {
            x = args.x,
            y = args.y,
            z = args.z,
        })
    else
        -- Reusable: set cooldown. cooldownSeconds is real seconds (#16).
        local cooldownSec = defaults.cooldownSeconds or 36
        cooldownSeconds = DeadwireNetwork.setCooldown(args.x, args.y, args.z, cooldownSec)
    end

    -- Degrade camo durability if camouflaged. Both branches write through to
    -- the save, or a reload restores camo the wire has already lost (#34).
    if wire.camouflaged then
        local degrade = DeadwireConfig.getSandbox("CamoTriggerDegrade", 15)
        local newDur = (wire.camoDurability or 0) - degrade
        if newDur <= 0 then
            DeadwireNetwork.setCamouflaged(args.x, args.y, args.z, false, 0)
            DeadwireWireManager.saveCamo(args.x, args.y, args.z, false, 0)
            sendServerCommand(DeadwireConfig.MODULE, "WireCamouflaged", {
                x = args.x, y = args.y, z = args.z,
                camouflaged = false, durability = 0,
            })
        else
            wire.camoDurability = newDur
            DeadwireWireManager.saveCamo(args.x, args.y, args.z, true, newDur)
        end
    end

    -- Log trigger if enabled
    if DeadwireConfig.getSandbox("LogWireTriggers", false) then
        local username = player:getUsername() or "SP"
        DeadwireConfig.log("Wire triggered: " .. wireType .. " at "
            .. args.x .. "," .. args.y .. "," .. args.z .. " by " .. username)
    end

    -- Broadcast to all clients: sound for MP audio, cooldownSeconds so their
    -- local WireNetwork agrees the wire is spent. Detection runs client-side
    -- against the client's own copy, so without this the cooldown existed only
    -- on the server and every reusable wire re-armed instantly for every client
    -- in MP. Tanglefoot has no sound and still needs the cooldown, so the
    -- broadcast is no longer conditional on soundName.
    if soundName or cooldownSeconds then
        sendServerCommand(DeadwireConfig.MODULE, "WireTriggered", {
            x = args.x,
            y = args.y,
            z = args.z,
            soundName = soundName,
            audioRadius = soundRadius,
            cooldownSeconds = cooldownSeconds,
        })
    end
end

-----------------------------------------------------------
-- CamouflageWire: Client requests camouflage application
-----------------------------------------------------------

handlers["CamouflageWire"] = function(player, args)
    if not DeadwireConfig.getSandbox("EnableCamouflage", true) then return end
    if not hasPosition(args) then return end

    local wire = DeadwireNetwork.getTile(args.x, args.y, args.z)
    if not wire or wire.camouflaged then return end

    -- TODO Sprint 4: Validate materials, skill checks, consume materials

    local durability = DeadwireConfig.getSandbox("CamoMaxDurability", 100)
    DeadwireNetwork.setCamouflaged(args.x, args.y, args.z, true, durability)
    DeadwireWireManager.saveCamo(args.x, args.y, args.z, true, durability)

    sendServerCommand(DeadwireConfig.MODULE, "WireCamouflaged", {
        x = args.x,
        y = args.y,
        z = args.z,
        camouflaged = true,
        durability = durability,
    })
end

-----------------------------------------------------------
-- RequestWireSync: a joining client asks for the wire list
--
-- Replaces the Events.OnPlayerConnect hook that never existed (#33). The
-- client cannot be pushed to at a moment the server knows about, so it asks
-- for itself from OnGameStart, and the answer goes to that player alone via
-- the targeted overload sendServerCommand(IsoPlayer, String, String, table),
-- which does exist in 42.20.4.
--
-- Nothing happens here in single player: sendServerCommand is a no-op off a
-- dedicated server, and single player does not need it -- both halves of the
-- mod share one tileIndex in memory.
-----------------------------------------------------------

handlers["RequestWireSync"] = function(player, args)
    if not player then return end

    local wireList = DeadwireWireManager.buildSyncPayload()
    sendServerCommand(player, DeadwireConfig.MODULE, "WireNetworkSync", {
        wires = wireList,
    })
    DeadwireConfig.log("WireNetworkSync: sent " .. #wireList .. " wires to "
        .. (player:getUsername() or "SP"))
end

-----------------------------------------------------------
-- DebugPlaceWire: Place a test wire at the player's feet
-- Admin or DEBUG mode only. For Sprint 1 testing.
-----------------------------------------------------------

handlers["DebugPlaceWire"] = function(player, args)
    if not DeadwireConfig.DEBUG and not isPrivileged(player) then
        return
    end

    local sq = player:getSquare()
    if not sq then return end

    local x, y, z = sq:getX(), sq:getY(), sq:getZ()
    local wireType = (args and args.wireType) or DeadwireConfig.WireTypes.TIN_CAN
    local username = player:getUsername() or "SP"

    -- Remove existing wire at this position first
    if DeadwireNetwork.getTile(x, y, z) then
        DeadwireWireManager.destroyWire(x, y, z)
    end

    local networkId = DeadwireNetwork.generateNetworkId()
    local obj = DeadwireWireManager.createWire(sq, wireType, username, networkId)
    if not obj then return end

    DeadwireConfig.log("DEBUG wire at " .. x .. "," .. y .. "," .. z .. " type=" .. wireType)

    sendServerCommand(DeadwireConfig.MODULE, "WirePlaced", {
        x = x,
        y = y,
        z = z,
        networkId = networkId,
        wireType = wireType,
        ownerId = username,
    })
end

-----------------------------------------------------------
-- DebugListWires: List all registered wires (admin/debug)
-----------------------------------------------------------

handlers["DebugListWires"] = function(player, args)
    if not DeadwireConfig.DEBUG and not isPrivileged(player) then
        return
    end

    local count = 0
    for key, entry in pairs(DeadwireNetwork.getAllTiles()) do
        DeadwireConfig.log("  Wire: " .. key .. " type=" .. entry.wireType
            .. " active=" .. tostring(entry.active)
            .. " owner=" .. tostring(entry.ownerId))
        count = count + 1
    end
    DeadwireConfig.log("Total wires: " .. count)
end

-----------------------------------------------------------
-- Event Registration
-----------------------------------------------------------

Events.OnClientCommand.Add(onClientCommand)
DeadwireConfig.log("ServerCommands initialized")
