-- Deadwire WireNetwork: Hash-table tile index for O(1) detection lookup
-- Shared: runs on both client and server
--
-- Primary data structure for the entire mod. OnZombieUpdate calls getTile()
-- every zombie tick — must be fast. String-key hash table gives O(1) lookup.

require "Deadwire/Config"

DeadwireNetwork = DeadwireNetwork or {}

-- Primary tile index: "x,y,z" -> wire entry
local tileIndex = {}

-- Network index: networkId -> { tiles = {"x,y,z", ...}, wireType, ownerId }
local networks = {}

-- Camouflaged tile subset for efficient client-side iteration
local camoTiles = {}

-- Server-side network ID counter
local nextNetworkId = 1

-----------------------------------------------------------
-- Key Helpers
-----------------------------------------------------------

function DeadwireNetwork.tileKey(x, y, z)
    return x .. "," .. y .. "," .. z
end

function DeadwireNetwork.parseKey(key)
    local x, y, z
    local i = 1
    for part in string.gmatch(key, "[^,]+") do
        if i == 1 then x = tonumber(part)
        elseif i == 2 then y = tonumber(part)
        elseif i == 3 then z = tonumber(part)
        end
        i = i + 1
    end
    return x, y, z
end

-----------------------------------------------------------
-- Network ID Generation (server only)
-----------------------------------------------------------

function DeadwireNetwork.generateNetworkId()
    local id = nextNetworkId
    nextNetworkId = nextNetworkId + 1
    return id
end

-----------------------------------------------------------
-- Tile Registration
-----------------------------------------------------------

function DeadwireNetwork.registerTile(x, y, z, networkId, wireType, ownerId)
    local key = DeadwireNetwork.tileKey(x, y, z)

    -- Idempotent: if already registered, update fields and return existing.
    -- Prevents duplicate entries when both server and client register the
    -- same tile (host machine in MP receives its own WirePlaced broadcast).
    if tileIndex[key] then
        local existing = tileIndex[key]
        existing.networkId = networkId
        existing.wireType = wireType
        existing.ownerId = ownerId
        existing.active = true
        return existing
    end

    local entry = {
        networkId = networkId,
        wireType = wireType,
        active = true,
        x = x,
        y = y,
        z = z,
        ownerId = ownerId,
        camouflaged = false,
        camoDurability = 0,
        cooldownUntil = 0,
        isoObject = nil,
    }
    tileIndex[key] = entry

    if not networks[networkId] then
        networks[networkId] = {
            tiles = {},
            wireType = wireType,
            ownerId = ownerId,
        }
    end
    table.insert(networks[networkId].tiles, key)

    DeadwireConfig.debugLog("Registered tile " .. key .. " network=" .. networkId .. " type=" .. wireType)
    return entry
end

function DeadwireNetwork.unregisterTile(x, y, z)
    local key = DeadwireNetwork.tileKey(x, y, z)
    local entry = tileIndex[key]
    if not entry then return end

    local network = networks[entry.networkId]
    if network then
        for i, tileKey in ipairs(network.tiles) do
            if tileKey == key then
                table.remove(network.tiles, i)
                break
            end
        end
        if #network.tiles == 0 then
            networks[entry.networkId] = nil
        end
    end

    if entry.camouflaged then
        camoTiles[key] = nil
    end

    tileIndex[key] = nil
    DeadwireConfig.debugLog("Unregistered tile " .. key)
end

-----------------------------------------------------------
-- Tile Lookup (called from OnZombieUpdate — must be fast)
-----------------------------------------------------------

function DeadwireNetwork.getTile(x, y, z)
    return tileIndex[DeadwireNetwork.tileKey(x, y, z)]
end

-----------------------------------------------------------
-- Network Queries
-----------------------------------------------------------

function DeadwireNetwork.getNetworkTiles(networkId)
    local network = networks[networkId]
    if not network then return {} end
    local tiles = {}
    for _, key in ipairs(network.tiles) do
        local entry = tileIndex[key]
        if entry then
            table.insert(tiles, entry)
        end
    end
    return tiles
end

function DeadwireNetwork.getNetwork(networkId)
    return networks[networkId]
end

-----------------------------------------------------------
-- Camouflage
-----------------------------------------------------------

function DeadwireNetwork.setCamouflaged(x, y, z, camouflaged, durability)
    local key = DeadwireNetwork.tileKey(x, y, z)
    local entry = tileIndex[key]
    if not entry then return end

    entry.camouflaged = camouflaged
    entry.camoDurability = durability or 0

    if camouflaged then
        camoTiles[key] = entry
    else
        camoTiles[key] = nil
    end
end

function DeadwireNetwork.getCamoTiles()
    return camoTiles
end

-----------------------------------------------------------
-- IsoObject Reference (client-side)
-----------------------------------------------------------

function DeadwireNetwork.setIsoObject(x, y, z, obj)
    local entry = tileIndex[DeadwireNetwork.tileKey(x, y, z)]
    if entry then
        entry.isoObject = obj
    end
end

-----------------------------------------------------------
-- Cooldown
-----------------------------------------------------------

function DeadwireNetwork.isOnCooldown(x, y, z)
    local entry = tileIndex[DeadwireNetwork.tileKey(x, y, z)]
    if not entry or entry.cooldownUntil <= 0 then return false end
    return getGameTime():getWorldAgeHours() < entry.cooldownUntil
end

function DeadwireNetwork.setCooldown(x, y, z, durationHours)
    local entry = tileIndex[DeadwireNetwork.tileKey(x, y, z)]
    if entry then
        entry.cooldownUntil = getGameTime():getWorldAgeHours() + durationHours
    end
end

-----------------------------------------------------------
-- Player Wire Count
-----------------------------------------------------------

function DeadwireNetwork.getPlayerTileCount(ownerId)
    local count = 0
    for _, entry in pairs(tileIndex) do
        if entry.ownerId == ownerId then
            count = count + 1
        end
    end
    return count
end

-----------------------------------------------------------
-- Utility
-----------------------------------------------------------

function DeadwireNetwork.getAllTiles()
    return tileIndex
end

function DeadwireNetwork.clear()
    tileIndex = {}
    networks = {}
    camoTiles = {}
    nextNetworkId = 1
end

function DeadwireNetwork.setNextNetworkId(id)
    nextNetworkId = id
end
