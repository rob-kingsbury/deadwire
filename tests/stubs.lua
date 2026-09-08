-- tests/stubs.lua
-- PZ API stubs: lets Deadwire Lua modules load and run outside the game engine.
-- Load this before requiring any Deadwire module.
-- All stub state can be reset with _reset() between tests.

-----------------------------------------------------------------
-- Events (PZ event system)
-- Events.SomeName.Add(fn) stores handlers we can invoke in tests.
--
-- This table used to invent any event name it was asked for. That is how
-- Events.OnPlayerConnect -- a name in none of the jar's 23,740 classes, which
-- threw at load in every run mode and meant the join-time wire sync never ran
-- once -- passed 159 tests for a whole release (#33).
--
-- A checker that supplies whatever it is asked for cannot detect an absence.
-- So the allow-list comes from the game itself: tests/pz_events.lua is
-- generated from zombie/Lua/LuaEventManager by
-- `python scripts/verify_names.py --update-events`, and verify_names fails if
-- the committed copy has drifted from the installed jar. The list is committed
-- so the suite still runs on a machine with no game installed.
-----------------------------------------------------------------
local ok, KNOWN_EVENTS = pcall(dofile, "tests/pz_events.lua")
if not ok or type(KNOWN_EVENTS) ~= "table" then
    error("tests/pz_events.lua is missing or unreadable. Run:\n"
        .. "  python scripts/verify_names.py --update-events\n"
        .. "(run the suite from the repo root)")
end

Events = {}
setmetatable(Events, {
    __index = function(t, k)
        if not KNOWN_EVENTS[k] then
            error("Events." .. tostring(k) .. " is not an event this game has.\n"
                .. "Registering it would throw at load and everything after that\n"
                .. "line in the file would never run. Check the name against\n"
                .. "tests/pz_events.lua.", 2)
        end
        local ev = { _handlers = {} }
        -- Add: called with dot syntax in PZ code, e.g. Events.OnZombieUpdate.Add(fn)
        ev.Add  = function(fn) table.insert(ev._handlers, fn) end
        -- Fire: called with colon syntax in tests, e.g. Events.OnZombieUpdate:Fire(zombie)
        -- Colon passes the table as first arg; remaining args go to handlers.
        ev.Fire = function(_, ...) for _, fn in ipairs(ev._handlers) do fn(...) end end
        t[k] = ev
        return ev
    end
})

-----------------------------------------------------------------
-- Run mode
--
-- isClient() is true ONLY on a multiplayer client. It is false in single
-- player AND on a dedicated server, which is why it, and not isServer(), is
-- the guard for "the authoritative side". Defaults to false, so a module that
-- forgets the guard is exercised in the mode most tests mean.
--
-- isServer() is deliberately not stubbed. Nothing under test calls it, and a
-- stub that answers questions nobody asked is how three checkers here have
-- blessed a bug.
-----------------------------------------------------------------
local _isClient = false
function isClient() return _isClient end
function _setClient(v) _isClient = v and true or false end

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
    local movers = {}
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

        -- What ISDeadwireTripLine:isValid asks a square. Both start in the
        -- state that lets a wire be placed; a test that cares about refusal
        -- sets the field itself, so neither answer is invented here.
        _vehicleIntersecting = false,
        _freeOrMidair = true,
        isVehicleIntersecting = function(self) return self._vehicleIntersecting end,
        isFreeOrMidair = function(self) return self._freeOrMidair end,

        -- Live zombies and players on this tile. Real IsoGridSquare returns an
        -- ArrayList here, hence size()/get(i) with a zero base. Starts empty
        -- and only ever holds what a test explicitly put there -- the server's
        -- trigger gate reads this to decide whether anything actually walked
        -- into a wire, so a stub that invented occupants could not tell an
        -- empty tile from an occupied one.
        getMovingObjects = function(self)
            return {
                size = function() return #movers end,
                get  = function(_, i) return movers[i + 1] end,
            }
        end,
        _addMover = function(self, obj)
            table.insert(movers, obj)
        end,
    }
    _squares[key] = sq
    return sq
end

-- Put an existing mock entity on a square. _mockZombie and _mockPlayer call
-- this for themselves when their square exists.
function _placeOn(entity, x, y, z)
    local sq = _squares[x .. "," .. y .. "," .. z]
    if sq then sq:_addMover(entity) end
    return entity
end

-- Walk an entity to another tile, keeping its modData. The old tile keeps the
-- reference in its moving-objects list, which does not matter for anything
-- currently under test and is not worth pretending otherwise about.
function _moveTo(entity, x, y, z)
    entity._sq = _squares[x .. "," .. y .. "," .. z]
    return _placeOn(entity, x, y, z)
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
-- instanceof (PZ global, used to tell IsoZombie from IsoPlayer)
--
-- Answers from the class the mock declares for itself. A mock that declares
-- nothing is not an instance of anything, so asking about a class no mock
-- sets is false rather than true -- the opposite of the Events table's old
-- behaviour, which invented whatever it was asked for.
-----------------------------------------------------------------
function instanceof(obj, className)
    if type(obj) ~= "table" then return false end
    return obj._class == className
end

-----------------------------------------------------------------
-- Command capture: sendServerCommand / sendClientCommand
-----------------------------------------------------------------
_sentServer = {}
_sentClient = {}

-- Both real overloads exist and PZ picks by the first argument's type:
--   sendServerCommand(module, command, table)             -> every client
--   sendServerCommand(player, module, command, table)     -> that one client
-- Recording only the 3-arg shape would have silently shifted every field by one
-- for the targeted send the join sync uses (#33).
local function _isPlayer(v)
    return type(v) == "table" and v._class == "IsoPlayer"
end

function sendServerCommand(a, b, c, d)
    if _isPlayer(a) then
        table.insert(_sentServer, { target = a, mod = b, cmd = c, args = d })
    else
        table.insert(_sentServer, { target = nil, mod = a, cmd = b, args = c })
    end
end
function sendClientCommand(a, b, c, d)
    if _isPlayer(a) then
        table.insert(_sentClient, { target = a, mod = b, cmd = c, args = d })
    else
        table.insert(_sentClient, { target = nil, mod = a, cmd = b, args = c })
    end
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
            _alpha = 1.0, _outline = false,
            setName                      = function() end,
            setMaxHealth                 = function() end,
            setHealth                    = function() end,
            setCanPassThrough            = function() end,
            setBlockAllTheSquare         = function() end,
            setIsThumpable               = function() end,
            getModData                   = function(self) return self._modData end,
            getSquare                    = function(self) return self._sq end,
            transmitCompleteItemToClients = function() end,
            -- Visual state, recorded so tests can assert an uncamouflaged wire
            -- was actually made visible again rather than merely dropped from
            -- the camo index.
            setAlphaAndTarget    = function(self, a) self._alpha = a end,
            setOutlineHighlight  = function(self, v) self._outline = v end,
            setOutlineHighlightCol = function() end,
        }
        if sq then sq:AddSpecialObject(obj) end
        return obj
    end,
}

-----------------------------------------------------------------
-- ISBuildingObject stub
--
-- Enough of the vanilla base class for ISDeadwireTripLine to derive from it
-- and be constructed. derive() mirrors ISBaseObject: a fresh table whose
-- __index is the parent, so methods inherit and fields do not. The setters
-- record, because "did new() resolve a sprite for this wire type" is a thing
-- worth asserting.
-----------------------------------------------------------------
ISBuildingObject = {}

function ISBuildingObject:derive(name)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.Type = name
    return o
end

function ISBuildingObject:init() end
function ISBuildingObject:setSprite(s) self.sprite = s end
function ISBuildingObject:setNorthSprite(s) self.northSprite = s end
function ISBuildingObject.render() end

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
-- os.time stub (controls the dedup window in Detection.lua)
-- Detection uses os.time() with a 1-real-second dedup window.
-----------------------------------------------------------------
local _osTime = 0
local _orig_os_time = os.time
os.time = function() return _osTime end
function _setOsTime(t) _osTime = t end   -- test control

-----------------------------------------------------------------
-- Faction stub (Detection.lua faction immunity)
-- Real signature: Faction.isInSameFaction(IsoPlayer, String) -> boolean.
-- Tests declare membership by username via _setFaction.
-----------------------------------------------------------------
local _factions = {}   -- username -> faction name

Faction = {
    isInSameFaction = function(player, ownerUsername)
        if not player or not ownerUsername then return false end
        local mine = _factions[player:getUsername()]
        return mine ~= nil and mine == _factions[ownerUsername]
    end,
}

function _setFaction(username, factionName) _factions[username] = factionName end
function _clearFactions() _factions = {} end

-----------------------------------------------------------------
-- PZ capability system stub
-- UseBuildCheat is the real 42.20 name. CanBuildAnywhere, which this stub
-- used to declare, does not exist in the game -- so the stub was validating
-- a call that could never work. Deliberately the only key defined: any other
-- Capability.X in mod code resolves to nil here and fails loudly.
-----------------------------------------------------------------
Capability = { UseBuildCheat = "UseBuildCheat" }

-----------------------------------------------------------------
-- Sound stubs (no-op; we only care about logic, not audio)
-- getWorldSoundManager():addSound(emitter, x, y, z, radius, volume, blocked)
-- Called with colon syntax, so arg layout is: self, emitter, x, y, z, radius, volume, blocked
-----------------------------------------------------------------
local _soundCalls = {}
function getWorldSoundManager()
    return {
        addSound = function(_, emitter, x, y, z, radius, volume, blocked)
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
    local z_ = {
        _class      = "IsoZombie",
        _sq         = sq,
        isAlive     = function() return alive ~= false end,
        getSquare   = function(self) return self._sq end,
        getModData  = function() return modData end,
        getUsername = function() return nil end,
    }
    return _placeOn(z_, x, y, z)
end

-- Inventory stub: only the container methods Deadwire actually calls.
local function _makeInventory()
    local inv = { _items = {} }
    inv.getFirstTypeRecurse = function(self, fullType)
        for _, it in ipairs(self._items) do
            if it.fullType == fullType then return it end
        end
        return nil
    end
    inv.getItemsFromFullType = function(self, fullType, _recurse)
        local found = {}
        for _, it in ipairs(self._items) do
            if it.fullType == fullType then table.insert(found, it) end
        end
        return {
            size = function() return #found end,
            get  = function(_, i) return found[i + 1] end,
        }
    end
    inv.Remove = function(self, item)
        for i, it in ipairs(self._items) do
            if it == item then table.remove(self._items, i); return end
        end
    end
    return inv
end

-- Put an item in a mock player's inventory. Returns the item table.
function _giveItem(player, fullType)
    local item = { fullType = fullType }
    table.insert(player:getInventory()._items, item)
    return item
end

function _countItems(player, fullType)
    local n = 0
    for _, it in ipairs(player:getInventory()._items) do
        if it.fullType == fullType then n = n + 1 end
    end
    return n
end

function _mockPlayer(x, y, z, username)
    local modData = {}
    local sq = _squares[x .. "," .. y .. "," .. z]
    local inv = _makeInventory()
    local p = {
        _class        = "IsoPlayer",
        _sq           = sq,
        isAlive       = function() return true end,
        getSquare     = function(self) return self._sq end,
        getModData    = function() return modData end,
        getUsername   = function() return username or "testplayer" end,
        getInventory  = function() return inv end,
        isAccessLevel = function() return false end,
        getPlayerNum  = function() return 0 end,
        getRole       = function() return {
            hasCapability = function() return false end
        } end,
    }
    return _placeOn(p, x, y, z)
end

function _mockAdmin(x, y, z, username)
    local p = _mockPlayer(x, y, z, username)
    p.isAccessLevel = function() return true end
    p.getRole = function() return {
        hasCapability = function(_, cap) return cap == Capability.UseBuildCheat end
    } end
    return p
end

-- A player whose getRole() returns nil, as happens in single player. This used
-- to throw on `player:getRole():hasCapability(...)`.
function _mockRolelessPlayer(x, y, z, username)
    local p = _mockPlayer(x, y, z, username)
    p.getRole = function() return nil end
    return p
end

-----------------------------------------------------------------
-- Global reset: call between test suites for clean slate
-----------------------------------------------------------------
function _reset()
    _isClient = false
    _worldAgeHours = 0
    _osTime = 0
    _squares = {}
    _modStore = {}
    _sentServer = {}
    _sentClient = {}
    _soundCalls = {}
    _factions = {}
    SandboxVars = { Deadwire = {} }
    -- Reset WireNetwork internal state (if loaded)
    if DeadwireNetwork then DeadwireNetwork.clear() end
end
