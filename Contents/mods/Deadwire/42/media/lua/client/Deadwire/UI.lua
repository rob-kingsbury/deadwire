-- Deadwire UI: Context menu for wire placement and removal
-- Client: adds right-click options on ground tiles and placed wires

require "Deadwire/Config"
require "Deadwire/WireNetwork"
-- ISDeadwireTripLine is a global from server/BuildActions.lua (loaded before callbacks fire)

DeadwireUI = DeadwireUI or {}

-----------------------------------------------------------
-- Helpers
-----------------------------------------------------------

-- Friendly display names for wireType keys
local wireDisplayNames = {
    tin_can_tripline    = "Tin Can Trip Line",
    reinforced_tripline = "Reinforced Trip Line",
    bell_tripline       = "Bell Trip Line",
    tanglefoot          = "Tanglefoot",
}

-- Check if player has the required kit item for a wire type
local function hasKitItem(character, wireType)
    local kitItem = DeadwireConfig.KitItems[wireType]
    if not kitItem then return true end -- no kit required for this type
    return character:getInventory():getFirstTypeRecurse(kitItem) ~= nil
end

-- Count how many kit items the player has
local function countKitItems(character, wireType)
    local kitItem = DeadwireConfig.KitItems[wireType]
    if not kitItem then return -1 end -- no kit required
    local items = character:getInventory():getItemsFromFullType(kitItem, true)
    return items and items:size() or 0
end

-----------------------------------------------------------
-- Placement Menu
-----------------------------------------------------------

local function onPlaceWire(worldObjects, character, wireType)
    local tripLine = ISDeadwireTripLine:new(character, wireType)
    getCell():setDrag(tripLine, character:getPlayerNum())
end

-----------------------------------------------------------
-- Removal Menu
-----------------------------------------------------------

local function onRemoveWire(worldObjects, character, x, y, z)
    sendClientCommand(DeadwireConfig.MODULE, "RemoveWire", {
        x = x,
        y = y,
        z = z,
    })
end

-----------------------------------------------------------
-- Context Menu Hook
-----------------------------------------------------------

local function onFillWorldObjectContextMenu(playerNum, context, worldObjects, test)
    if test then return end
    if not DeadwireConfig.getSandbox("EnableMod", true) then return end

    local character = getSpecificPlayer(playerNum)
    if not character then return end

    -- Find the ground square from world objects
    local square = nil
    for i = 1, #worldObjects do
        local obj = worldObjects[i]
        if obj and instanceof(obj, "IsoObject") then
            square = obj:getSquare()
            if square then break end
        end
    end
    if not square then return end

    local x, y, z = square:getX(), square:getY(), square:getZ()
    local existingWire = DeadwireNetwork.getTile(x, y, z)

    if existingWire then
        -- Wire exists on this tile: show removal option
        local username = character:getUsername() or "SP"
        local isOwner = existingWire.ownerId == username
        local isAdmin = character:isAccessLevel("admin")

        if isOwner or isAdmin then
            local friendlyName = wireDisplayNames[existingWire.wireType] or existingWire.wireType
            local label = "Remove " .. friendlyName
            context:addOption(label, worldObjects, onRemoveWire, character, x, y, z)
        end
    else
        -- No wire: show placement submenu only if player has any kits
        local wireTypes = {
            { type = DeadwireConfig.WireTypes.TIN_CAN, label = "Tin Can Trip Line", tier = 0 },
            { type = DeadwireConfig.WireTypes.REINFORCED, label = "Reinforced Trip Line", tier = 1 },
            { type = DeadwireConfig.WireTypes.BELL, label = "Bell Trip Line", tier = 1 },
            { type = DeadwireConfig.WireTypes.TANGLEFOOT, label = "Tanglefoot", tier = 1 },
        }

        -- Build list of placeable wire types (tier enabled + has kit in inventory)
        local available = {}
        for _, wire in ipairs(wireTypes) do
            if DeadwireConfig.isTierEnabled(wire.tier) then
                local kitItem = DeadwireConfig.KitItems[wire.type]
                if kitItem then
                    local count = countKitItems(character, wire.type)
                    if count > 0 then
                        available[#available + 1] = { wire = wire, count = count }
                    end
                end
            end
        end

        -- Only show submenu if player has at least one kit
        if #available > 0 then
            local placeMenu = ISContextMenu:getNew(context)
            context:addSubMenu(
                context:addOption("Place Deadwire..."),
                placeMenu
            )

            for _, entry in ipairs(available) do
                local label = entry.wire.label .. " (" .. entry.count .. ")"
                placeMenu:addOption(label, worldObjects, onPlaceWire, character, entry.wire.type)
            end
        end
    end
end

Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)
DeadwireConfig.debugLog("UI context menus initialized (client)")
