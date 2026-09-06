-- Deadwire EventHandlers: OnServerCommand listener
-- Client: handles server broadcasts for sound effects and local state updates
--
-- When the server triggers a wire, it broadcasts to all clients. This module
-- plays the appropriate sound effect and updates the local WireNetwork cache.

require "Deadwire/Config"
require "Deadwire/WireNetwork"

DeadwireEventHandlers = DeadwireEventHandlers or {}

local handlers = {}

-- DRY: validate args contain position fields
local function hasPosition(args)
    return args and args.x and args.y and args.z
end

-- DRY: validate position args and return grid square (or nil)
local function getSquareFromArgs(args)
    if not hasPosition(args) then return nil end
    return getCell():getGridSquare(args.x, args.y, args.z)
end

-- Find the wire's IsoThumpable on its square and cache the reference.
-- CamoVisibility needs it to fade a wire, and destroyWire needs it to remove
-- one. LoadGridsquare supplies it for chunks that load later; this covers the
-- ones already loaded when the command arrives.
local function cacheIsoObject(x, y, z)
    local sq = getCell():getGridSquare(x, y, z)
    if not sq then return false end

    local objects = sq:getSpecialObjects()
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        if obj and obj:getModData() and obj:getModData()["dw_type"] then
            DeadwireNetwork.setIsoObject(x, y, z, obj)
            return true
        end
    end
    return false
end

-----------------------------------------------------------
-- Main Dispatcher
-----------------------------------------------------------

local function onServerCommand(module, command, args)
    if module ~= DeadwireConfig.MODULE then return end

    local handler = handlers[command]
    if handler then
        handler(args)
    else
        DeadwireConfig.debugLog("Unknown server command: " .. command)
    end
end

-----------------------------------------------------------
-- WireTriggered: Play sound effect and apply the server's cooldown
--
-- Detection (Detection.lua) checks isOnCooldown against this client's own
-- WireNetwork copy, so the server's cooldown has to be mirrored here or the
-- wire re-arms immediately on every client in MP.
-----------------------------------------------------------

handlers["WireTriggered"] = function(args)
    if not hasPosition(args) then return end

    if args.cooldownSeconds then
        DeadwireNetwork.setCooldown(args.x, args.y, args.z, args.cooldownSeconds)
    end

    -- No soundName means a silent trap (tanglefoot). Do not substitute one:
    -- the previous default of TIN_CAN_RATTLE would have made it audible.
    if not args.soundName then return end

    local sq = getSquareFromArgs(args)
    if not sq then return end

    local audioRadius = args.audioRadius or 15
    getSoundManager():PlayWorldSound(args.soundName, sq, 0, audioRadius, 1.0, false)
    DeadwireConfig.debugLog("Sound: " .. args.soundName .. " at " .. args.x .. "," .. args.y .. "," .. args.z)
end

-----------------------------------------------------------
-- WirePlaced: Update local wire network cache
-----------------------------------------------------------

handlers["WirePlaced"] = function(args)
    if not hasPosition(args) then return end
    DeadwireNetwork.registerTile(
        args.x, args.y, args.z,
        args.networkId,
        args.wireType,
        args.ownerId
    )

    -- Cache the IsoObject reference for client-side camo visibility
    cacheIsoObject(args.x, args.y, args.z)

    DeadwireConfig.debugLog("Wire placed at " .. args.x .. "," .. args.y .. "," .. args.z)
end

-----------------------------------------------------------
-- WireDestroyed: Remove from local cache
-----------------------------------------------------------

handlers["WireDestroyed"] = function(args)
    if not hasPosition(args) then return end

    DeadwireNetwork.unregisterTile(args.x, args.y, args.z)
    DeadwireConfig.debugLog("Wire destroyed at " .. args.x .. "," .. args.y .. "," .. args.z)
end

-----------------------------------------------------------
-- WireCamouflaged: Update local camouflage state
-----------------------------------------------------------

handlers["WireCamouflaged"] = function(args)
    if not hasPosition(args) then return end

    -- When uncamouflaging: reset alpha to full opacity before removing from
    -- camo index. Without this the wire stays invisible until next render cycle.
    if not args.camouflaged then
        local entry = DeadwireNetwork.getTile(args.x, args.y, args.z)
        if entry and entry.isoObject then
            entry.isoObject:setAlphaAndTarget(1.0)
            entry.isoObject:setOutlineHighlight(false)
        end
    end

    DeadwireNetwork.setCamouflaged(
        args.x, args.y, args.z,
        args.camouflaged,
        args.durability
    )
    DeadwireConfig.debugLog("Camo updated at " .. args.x .. "," .. args.y .. "," .. args.z)
end

-----------------------------------------------------------
-- WireNetworkSync: Bulk-populate local WireNetwork on join.
--
-- The server answers this to one player in reply to RequestWireSync below.
-- Until #33 it was hung off an event that does not exist, so a joining client
-- had an empty WireNetwork: detection ignored every existing wire, the context
-- menu never offered Remove on the player's own wire, and CamoVisibility hid
-- nothing.
--
-- The per-wire object lookup is not optional here. Chunks around the spawn
-- point are already loaded by the time this arrives and LoadGridsquare will
-- not fire for them again, so without it those wires never get an isoObject.
-----------------------------------------------------------

handlers["WireNetworkSync"] = function(args)
    if not args or not args.wires then return end
    local count = 0
    local linked = 0
    for _, wire in ipairs(args.wires) do
        if wire.x and wire.y and wire.z and wire.networkId and wire.wireType then
            DeadwireNetwork.registerTile(
                wire.x, wire.y, wire.z,
                wire.networkId,
                wire.wireType,
                wire.ownerId
            )
            if wire.camouflaged then
                DeadwireNetwork.setCamouflaged(
                    wire.x, wire.y, wire.z, true, wire.camoDurability or 0
                )
            end
            if cacheIsoObject(wire.x, wire.y, wire.z) then
                linked = linked + 1
            end
            count = count + 1
        end
    end
    DeadwireConfig.log("WireNetworkSync: registered " .. count
        .. " wires (" .. linked .. " already in loaded chunks)")
end

-----------------------------------------------------------
-- ElectricZap: Play zap sound (Phase 3, but handler ready)
-----------------------------------------------------------

handlers["ElectricZap"] = function(args)
    local sq = getSquareFromArgs(args)
    if not sq then return end

    getSoundManager():PlayWorldSound(
        args.soundName or DeadwireConfig.Sounds.ELEC_ZAP,
        sq, 0, args.audioRadius or 15, 1.0, false
    )
end

-----------------------------------------------------------
-- Ask the server for the wire list once the world is up.
--
-- isClient() is true only on a multiplayer client, which is exactly who needs
-- this: single player shares one tileIndex between both halves of the mod, and
-- a dedicated server never runs client/ code at all.
-----------------------------------------------------------

local function onGameStart()
    if not isClient() then return end
    sendClientCommand(DeadwireConfig.MODULE, "RequestWireSync", {})
    DeadwireConfig.debugLog("RequestWireSync sent")
end

-----------------------------------------------------------
-- Event Registration
-----------------------------------------------------------

Events.OnServerCommand.Add(onServerCommand)
Events.OnGameStart.Add(onGameStart)
DeadwireConfig.log("Client EventHandlers initialized")
