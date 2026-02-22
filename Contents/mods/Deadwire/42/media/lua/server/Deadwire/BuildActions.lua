-- Deadwire BuildActions: ISBuildingObject derivative for wire placement
-- Server: ISBuildingObject and derivatives must be in server/ (PZ load order)
-- create() runs server-side in MP via PZ's ISBuildAction:perform
--
-- Sprint 2: No material checks. Free placement for testing mechanics.
-- Sprint 3 adds item consumption and skill requirements.

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

    local obj = DeadwireWireManager.createWire(sq, wireType, username, networkId)
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
    o:setSprite("construction_01_24")
    o:setNorthSprite("construction_01_24")
    o.character = character
    o.player = character:getPlayerNum()
    o.wireType = wireType or DeadwireConfig.WireTypes.TIN_CAN
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
