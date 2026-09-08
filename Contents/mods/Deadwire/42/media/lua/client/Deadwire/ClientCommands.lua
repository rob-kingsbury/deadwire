-- Deadwire ClientCommands: sendClientCommand wrappers
-- Client: clean API for sending requests to the server
--
-- Other client modules call these instead of raw sendClientCommand.
-- Keeps the module name and arg format in one place.

require "Deadwire/Config"

DeadwireClientCommands = DeadwireClientCommands or {}

-- There is no placeWire wrapper. Placement goes through ISDeadwireTripLine in
-- server/BuildActions.lua, which the engine validates and performs; the
-- PlaceWire server command it used to call was an unchecked second placement
-- path nothing ever used (#36).

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

function DeadwireClientCommands.wireTriggered(x, y, z, wireType)
    sendClientCommand(DeadwireConfig.MODULE, "WireTriggered", {
        x = x,
        y = y,
        z = z,
        wireType = wireType,
    })
end

-- The two below have no caller in the mod on purpose. Their caller is a person
-- at the debug console, which evaluates Lua, so
-- `DeadwireClientCommands.debugPlaceWire("bell_tripline")` is typeable in a
-- running game. The server handlers behind them refuse anyone who is neither an
-- admin nor running a DEBUG build.

function DeadwireClientCommands.debugPlaceWire(wireType)
    sendClientCommand(DeadwireConfig.MODULE, "DebugPlaceWire", {
        wireType = wireType,
    })
end

function DeadwireClientCommands.debugListWires()
    sendClientCommand(DeadwireConfig.MODULE, "DebugListWires", {})
end

DeadwireConfig.debugLog("ClientCommands initialized")
