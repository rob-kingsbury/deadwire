-- Deadwire UI: Context menu for wire placement and removal
-- Client: adds right-click options on ground tiles and placed wires
--
-- Sprint 2: All wire types available, no material cost.
-- Sprint 3 adds material checks and skill gating.

require "Deadwire/Config"
require "Deadwire/WireNetwork"
-- ISDeadwireTripLine is a global from server/BuildActions.lua (loaded before callbacks fire)

DeadwireUI = DeadwireUI or {}

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
            local label = "Remove Wire (" .. existingWire.wireType .. ")"
            context:addOption(label, worldObjects, onRemoveWire, character, x, y, z)
        end
    else
        -- No wire: show placement submenu
        local placeMenu = ISContextMenu:getNew(context)
        context:addSubMenu(
            context:addOption("Place Deadwire..."),
            placeMenu
        )

        -- Add an option for each enabled wire type
        local wireTypes = {
            { type = DeadwireConfig.WireTypes.TIN_CAN, label = "Tin Can Trip Line", tier = 0 },
            { type = DeadwireConfig.WireTypes.REINFORCED, label = "Reinforced Trip Line", tier = 1 },
            { type = DeadwireConfig.WireTypes.BELL, label = "Bell Trip Line", tier = 1 },
            { type = DeadwireConfig.WireTypes.TANGLEFOOT, label = "Tanglefoot", tier = 1 },
        }

        for _, wire in ipairs(wireTypes) do
            if DeadwireConfig.isTierEnabled(wire.tier) then
                placeMenu:addOption(wire.label, worldObjects, onPlaceWire, character, wire.type)
            end
        end
    end
end

Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)
DeadwireConfig.debugLog("UI context menus initialized (client)")
