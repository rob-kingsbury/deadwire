-- Deadwire BuildActions: ISBuildingObject derivative for wire placement
-- Client: handles the build cursor and ghost preview
-- Server: create() runs server-side in MP via PZ's createBuildAction
--
-- Sprint 2: No material checks. Free placement for testing mechanics.
-- Sprint 3 adds item consumption and skill requirements.

require "Deadwire/Config"
require "Deadwire/WireNetwork"

-----------------------------------------------------------
-- ISDeadwireTripLine: Buildable wire object
-----------------------------------------------------------

ISDeadwireTripLine = ISBuildingObject:derive("ISDeadwireTripLine")

function ISDeadwireTripLine:create(x, y, z, north, sprite)
    local sq = getCell():getGridSquare(x, y, z)
    if not sq then return end

    -- In MP, create() runs on the server via createBuildAction.
    -- Use WireManager if available (server), otherwise fall back to
    -- sendClientCommand (shouldn't happen but defensive).
    if DeadwireWireManager then
        local networkId = DeadwireNetwork.generateNetworkId()
        local username = self.character:getUsername() or "SP"
        local obj = DeadwireWireManager.createWire(sq, self.wireType, username, networkId)

        if obj then
            -- Broadcast to all clients
            sendServerCommand(DeadwireConfig.MODULE, "WirePlaced", {
                x = x,
                y = y,
                z = z,
                networkId = networkId,
                wireType = self.wireType,
                ownerId = username,
            })
        end
    else
        -- Fallback: client-only context (shouldn't reach here in MP)
        sendClientCommand(DeadwireConfig.MODULE, "PlaceWire", {
            x = x,
            y = y,
            z = z,
            wireType = self.wireType,
        })
    end
end

function ISDeadwireTripLine:new(character, wireType)
    local o = ISBuildingObject.new(self)
    o:init()
    o:setSprite("construction_01_24")  -- Vanilla barbed wire placeholder
    o:setNorthSprite("construction_01_24")
    o.character = character
    o.wireType = wireType or DeadwireConfig.WireTypes.TIN_CAN
    o.canBeAlwaysPlaced = true
    o.buildMid = true
    -- Sprint 2: No material cost
    o.noNeedHammer = true
    o.skipBuildAction = false
    return o
end

function ISDeadwireTripLine:isValid(square)
    if not square then return false end
    -- Can't place on occupied wire tile
    local x, y, z = square:getX(), square:getY(), square:getZ()
    if DeadwireNetwork.getTile(x, y, z) then return false end
    -- Basic walkability check
    if not square:isFreeOrMidair() then return false end
    return true
end

function ISDeadwireTripLine:render(x, y, z, square)
    ISBuildingObject.render(self, x, y, z, square)
end
