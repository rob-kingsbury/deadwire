-- tests/stubs.lua
-- PZ API stubs: lets Deadwire Lua modules load and run outside the game engine.
-- Load this before requiring any Deadwire module.
-- All stub state can be reset with _reset() between tests.

-----------------------------------------------------------------
-- Events (PZ event system)
-- Events.SomeName.Add(fn) stores handlers we can invoke in tests.
-----------------------------------------------------------------
Events = {}
setmetatable(Events, {
    __index = function(t, k)
        local ev = { _handlers = {} }
        ev.Add  = function(self, fn) table.insert(self._handlers, fn) end
        ev.Fire = function(self, ...)
            for _, fn in ipairs(self._handlers) do fn(...) end
        end
        t[k] = ev
        return ev
    end
})

-----------------------------------------------------------------
-- SandboxVars (overridable per test)
-----------------------------------------------------------------
SandboxVars = { Deadwire = {} }

-----------------------------------------------------------------
-- Game time (controls cooldown / dedup timestamp logic)
-----------------------------------------------------------------
local _worldAgeHours = 0
function getGameTime()
    return { getWorldAgeHours = function() return _worldAgeHours end }
end
function _setWorldAge(h) _worldAgeHours = h end  -- test control

-----------------------------------------------------------------
-- World cells and grid squares
-----------------------------------------------------------------
local _squares = {}

function _makeSquare(x, y, z)
    local key = x .. "," .. y .. "," .. z
    local objects = {}
    local sq = {
        _x = x, _y = y, _z = z,
        getX = function(self) return self._x end,
        getY = function(self) return self._y end,
        getZ = function(self) return self._z end,
        getSpecialObjects = function(self)
            return {
                size = function() return #objects end,
                get  = function(_, i) return objects[i + 1] end,
            }
        end,
        AddSpecialObject = function(self, obj)
            table.insert(objects, obj)
        end,
        transmitRemoveItemFromSquare = function(self, obj)
            for i, o in ipairs(objects) do
                if o == obj then table.remove(objects, i); return end
            end
        end,
        RecalcAllWithNeighbours = function() end,
    }
    _squares[key] = sq
    return sq
end

local _cell = {
    getGridSquare = function(self, x, y, z)
        return _squares[x .. "," .. y .. "," .. z]
    end,
}
function getCell()  return _cell end
function getWorld() return { getCell = function() return _cell end } end
function _clearSquares() _squares = {} end

-----------------------------------------------------------------
-- Command capture: sendServerCommand / sendClientCommand
-----------------------------------------------------------------
_sentServer = {}
_sentClient = {}

function sendServerCommand(mod, cmd, args)
    table.insert(_sentServer, { mod = mod, cmd = cmd, args = args })
end
function sendClientCommand(mod, cmd, args)
    table.insert(_sentClient, { mod = mod, cmd = cmd, args = args })
end
function _clearCommands()
    _sentServer = {}
    _sentClient = {}
end

-- Helper: find a sent server command by cmd name
function _findServerCmd(cmd)
    for _, entry in ipairs(_sentServer) do
        if entry.cmd == cmd then return entry end
    end
    return nil
end

-----------------------------------------------------------------
-- IsoThumpable stub
-----------------------------------------------------------------
IsoThumpable = {
    new = function(cell, sq, sprite, north, extra)
        local modData = {}
        local obj = {
            _sq = sq, _sprite = sprite, _modData = modData,
            setName                      = function() end,
            setMaxHealth                 = function() end,
            setHealth                    = function() end,
            setCanPassThrough            = function() end,
            setBlockAllTheSquare         = function() end,
            setIsThumpable               = function() end,
            getModData                   = function(self) return self._modData end,
            getSquare                    = function(self) return self._sq end,
            transmitCompleteItemToClients = function() end,
        }
        if sq then sq:AddSpecialObject(obj) end
        return obj
    end,
}

-----------------------------------------------------------------
-- ModData (GlobalModData persistence stub)
-----------------------------------------------------------------
local _modStore = {}
ModData = {
    getOrCreate = function(key)
        if not _modStore[key] then _modStore[key] = {} end
        return _modStore[key]
    end,
}
function _clearModData() _modStore = {} end

-----------------------------------------------------------------
-- Sound stubs (no-op; we only care about logic, not audio)
-----------------------------------------------------------------
local _soundCalls = {}
function getWorldSoundManager()
    return {
        addSound = function(_, x, y, z, radius, volume, _)
            table.insert(_soundCalls, { x=x, y=y, z=z, radius=radius, volume=volume })
        end
    }
end
function getSoundManager()
    return { PlayWorldSound = function() end }
end
function _clearSounds() _soundCalls = {} end
function _getSoundCalls() return _soundCalls end

-----------------------------------------------------------------
-- Entity builders for detection tests
-----------------------------------------------------------------
function _mockZombie(x, y, z, alive)
    local modData = {}
    local sq = _squares[x .. "," .. y .. "," .. z]
    return {
        isAlive     = function() return alive ~= false end,
        getSquare   = function() return sq end,
        getModData  = function() return modData end,
        getUsername = function() return nil end,
    }
end

function _mockPlayer(x, y, z, username)
    local modData = {}
    local sq = _squares[x .. "," .. y .. "," .. z]
    return {
        isAlive       = function() return true end,
        getSquare     = function() return sq end,
        getModData    = function() return modData end,
        getUsername   = function() return username or "testplayer" end,
        isAccessLevel = function() return false end,
    }
end

function _mockAdmin(x, y, z, username)
    local p = _mockPlayer(x, y, z, username)
    p.isAccessLevel = function() return true end
    return p
end

-----------------------------------------------------------------
-- Global reset: call between test suites for clean slate
-----------------------------------------------------------------
function _reset()
    _worldAgeHours = 0
    _squares = {}
    _modStore = {}
    _sentServer = {}
    _sentClient = {}
    _soundCalls = {}
    SandboxVars = { Deadwire = {} }
    -- Reset WireNetwork internal state (if loaded)
    if DeadwireNetwork then DeadwireNetwork.clear() end
end
