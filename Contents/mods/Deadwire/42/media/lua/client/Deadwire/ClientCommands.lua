-- Deadwire ClientCommands: sendClientCommand wrappers
-- Client: clean API for sending requests to the server
--
-- Other client modules call these instead of raw sendClientCommand.
-- Keeps the module name and arg format in one place.

require "Deadwire/Config"

DeadwireClientCommands = DeadwireClientCommands or {}

function DeadwireClientCommands.placeWire(x, y, z, wireType)
    sendClientCommand(DeadwireConfig.MODULE, "PlaceWire", {
        x = x,
        y = y,
        z = z,
        wireType = wireType,
    })
end

function DeadwireClientCommands.removeWire(x, y, z)
    sendClientCommand(DeadwireConfig.MODULE, "RemoveWire", {
        x = x,
        y = y,
        z = z,
    })
end

function DeadwireClientCommands.camouflageWire(x, y, z)
    sendClientCommand(DeadwireConfig.MODULE, "CamouflageWire", {
        x = x,
        y = y,
        z = z,
    })
end

function DeadwireClientCommands.debugPlaceWire(wireType)
    sendClientCommand(DeadwireConfig.MODULE, "DebugPlaceWire", {
        wireType = wireType,
    })
end

function DeadwireClientCommands.debugListWires()
    sendClientCommand(DeadwireConfig.MODULE, "DebugListWires", {})
end

DeadwireConfig.debugLog("ClientCommands initialized")
