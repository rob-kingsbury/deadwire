-- Deadwire BuildActions: ISBuildingObject derivative for wire placement
-- Server: ISBuildingObject and derivatives must be in server/ (PZ load order)
-- create() runs server-side in MP via PZ's ISBuildAction:perform

require "Deadwire/Config"
require "Deadwire/WireNetwork"
require "Deadwire/WireManager"

-----------------------------------------------------------
-- ISDeadwireTripLine: Buildable wire object
-----------------------------------------------------------

ISDeadwireTripLine = ISBuildingObject:derive("ISDeadwireTripLine")

function ISDeadwireTripLine:create(x, y, z, north, sprite)
    local sq = getWorld():getCell():getGridSquare(x, y, z)
    if not sq then return end

    local wireType = self.wireType or DeadwireConfig.WireTypes.TIN_CAN
    local username = self.character:getUsername() or "SP"
    local networkId = DeadwireNetwork.generateNetworkId()

    -- Consume kit item from inventory (if this wire type requires one)
    local kitItem = DeadwireConfig.KitItems[wireType]
    if kitItem then
        local inv = self.character:getInventory()
        local item = inv:getFirstTypeRecurse(kitItem)
        if item then
            inv:Remove(item)
        else
            DeadwireConfig.debugLog("BuildActions: missing kit " .. kitItem)
            return
        end
    end

    local obj = DeadwireWireManager.createWire(sq, wireType, username, networkId, north)
    if not obj then return end

    sendServerCommand(DeadwireConfig.MODULE, "WirePlaced", {
        x = x,
        y = y,
        z = z,
        networkId = networkId,
        wireType = wireType,
        ownerId = username,
    })
end

function ISDeadwireTripLine:new(character, wireType)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o:init()

    -- Set per-type sprites (fallback to vanilla barbed wire)
    local wt = wireType or DeadwireConfig.WireTypes.TIN_CAN
    local sprites = DeadwireConfig.Sprites[wt]
    local fallback = DeadwireConfig.FALLBACK_SPRITE
    o:setSprite(sprites and sprites.east or fallback)
    o:setNorthSprite(sprites and sprites.north or fallback)

    o.character = character
    o.player = character:getPlayerNum()
    o.wireType = wt
    o.name = "Trip Wire"
    o.canBeAlwaysPlaced = true
    o.noNeedHammer = true
    o.canPassThrough = true
    o.isWallLike = false
    o.actionAnim = "Loot"
    o.buildLow = true
    return o
end

function ISDeadwireTripLine:isValid(square)
    if not square then return false end
    local x, y, z = square:getX(), square:getY(), square:getZ()
    if DeadwireNetwork.getTile(x, y, z) then return false end
    if square:isVehicleIntersecting() then return false end
    if not square:isFreeOrMidair(true) then return false end
    return true
end

function ISDeadwireTripLine:render(x, y, z, square)
    ISBuildingObject.render(self, x, y, z, square)
end
