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

-- DRY: validate args contain position fields
local function hasPosition(args)
    return args and args.x and args.y and args.z
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

    -- Create IsoThumpable + register in WireNetwork + persist
    local networkId = DeadwireNetwork.generateNetworkId()
    local obj = DeadwireWireManager.createWire(sq, wireType, username, networkId)
    if not obj then
        DeadwireConfig.log("PlaceWire: WireManager.createWire failed")
        return
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
    if wire.ownerId ~= username and not player:isAccessLevel("admin") then
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

    local wire = DeadwireNetwork.getTile(args.x, args.y, args.z)
    if not wire then return end

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
    if defaults.breakOnTrigger then
        -- Single-use: destroy wire
        DeadwireWireManager.destroyWire(args.x, args.y, args.z)
        sendServerCommand(DeadwireConfig.MODULE, "WireDestroyed", {
            x = args.x,
            y = args.y,
            z = args.z,
        })
    else
        -- Reusable: set cooldown
        local cooldownSec = defaults.cooldownSeconds or 36
        local cooldownHours = cooldownSec / 3600
        DeadwireNetwork.setCooldown(args.x, args.y, args.z, cooldownHours)
    end

    -- Degrade camo durability if camouflaged
    if wire.camouflaged then
        local degrade = DeadwireConfig.getSandbox("CamoTriggerDegrade", 15)
        local newDur = (wire.camoDurability or 0) - degrade
        if newDur <= 0 then
            DeadwireNetwork.setCamouflaged(args.x, args.y, args.z, false, 0)
            sendServerCommand(DeadwireConfig.MODULE, "WireCamouflaged", {
                x = args.x, y = args.y, z = args.z,
                camouflaged = false, durability = 0,
            })
        else
            wire.camoDurability = newDur
        end
    end

    -- Log trigger if enabled
    if DeadwireConfig.getSandbox("LogWireTriggers", false) then
        local username = player:getUsername() or "SP"
        DeadwireConfig.log("Wire triggered: " .. wireType .. " at "
            .. args.x .. "," .. args.y .. "," .. args.z .. " by " .. username)
    end

    -- Broadcast to all clients for MP sound (detecting client already played locally)
    if soundName then
        sendServerCommand(DeadwireConfig.MODULE, "WireTriggered", {
            x = args.x,
            y = args.y,
            z = args.z,
            soundName = soundName,
            audioRadius = soundRadius,
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

    sendServerCommand(DeadwireConfig.MODULE, "WireCamouflaged", {
        x = args.x,
        y = args.y,
        z = args.z,
        camouflaged = true,
        durability = durability,
    })
end

-----------------------------------------------------------
-- DebugPlaceWire: Place a test wire at the player's feet
-- Admin or DEBUG mode only. For Sprint 1 testing.
-----------------------------------------------------------

handlers["DebugPlaceWire"] = function(player, args)
    if not DeadwireConfig.DEBUG and not player:isAccessLevel("admin") then
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
    if not DeadwireConfig.DEBUG and not player:isAccessLevel("admin") then
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
