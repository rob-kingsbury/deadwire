-- tests/test_build_actions.lua
-- Tests for ISDeadwireTripLine (server/BuildActions.lua).
--
-- This is the mod's only placement path. The engine builds and performs it:
-- in single player ISBuildAction:perform calls create(), and in multiplayer
-- the server rebuilds the object in BuildAction.parse and calls create() there.
-- Every gate that decides whether a wire may exist has to be inside create(),
-- because a modified client can reach it without ever opening our menu.
--
-- Until #36 the tier gate, the wire cap and the placement log lived in a
-- PlaceWire server command instead, which nothing called. Deleting that command
-- would have deleted the cap and the log with it; verify_names caught the two
-- orphaned sandbox options, and these tests are what keeps them honest here.

-----------------------------------------------------------------
-- WireManager mock: records, and registers so the tile is occupied after
-----------------------------------------------------------------
local _createdWires = {}

DeadwireWireManager.createWire = function(sq, wireType, ownerId, networkId, north)
    table.insert(_createdWires, {
        wireType = wireType, ownerId = ownerId, networkId = networkId, north = north,
    })
    local x, y, z = sq:getX(), sq:getY(), sq:getZ()
    DeadwireNetwork.registerTile(x, y, z, networkId, wireType, ownerId)
    return { _fake = true }
end

local function resetAll()
    _reset()
    _createdWires = {}
    _clearCommands()
end

-- Build the object the way UI.lua does, then perform it on a square.
local function place(character, wireType, x, y, z, north)
    local obj = ISDeadwireTripLine:new(wireType, character)
    obj:create(x, y, z, north or false, obj.sprite)
    return obj
end

local function _kitted(x, y, z, name, wireType)
    local player = _mockPlayer(x, y, z, name)
    _giveItem(player, DeadwireConfig.KitItems[wireType or "tin_can_tripline"])
    return player
end

-----------------------------------------------------------------
suite("BuildActions: ISDeadwireTripLine:new")
-----------------------------------------------------------------

test("character is the LAST argument, and wireType the first (#32)", function()
    resetAll()
    _makeSquare(1, 1, 0)
    local player = _mockPlayer(1, 1, 0, "alice")

    local obj = ISDeadwireTripLine:new("bell_tripline", player)

    assert_eq(obj.wireType, "bell_tripline",
        "the server harvests these by parameter name and drops the IsoPlayer; "
        .. "with character first, wireType came back nil")
    assert_eq(obj.character, player)
end)

test("each wire type gets its own pair of sprites", function()
    resetAll()
    local player = _mockPlayer(1, 1, 0, "alice")

    local obj = ISDeadwireTripLine:new("tanglefoot", player)

    assert_eq(obj.sprite, DeadwireConfig.Sprites.tanglefoot.east)
    assert_eq(obj.northSprite, DeadwireConfig.Sprites.tanglefoot.north)
end)

test("a type with no declared sprites substitutes nothing (#39)", function()
    resetAll()
    local player = _mockPlayer(1, 1, 0, "alice")

    local obj = ISDeadwireTripLine:new("electric_fence", player)

    assert_nil(obj.sprite, "a vanilla wall frame standing in for a wire looked like a working feature")
    assert_nil(obj.northSprite)
end)

-----------------------------------------------------------------
suite("BuildActions: ISDeadwireTripLine:create")
-----------------------------------------------------------------

test("valid placement: wire created, kit consumed, WirePlaced broadcast", function()
    resetAll()
    _makeSquare(10, 20, 0)
    local player = _kitted(10, 20, 0, "alice")

    place(player, "tin_can_tripline", 10, 20, 0)

    assert_eq(#_createdWires, 1, "createWire should have been called once")
    assert_eq(_createdWires[1].wireType, "tin_can_tripline")
    assert_eq(_createdWires[1].ownerId, "alice")
    assert_eq(_countItems(player, DeadwireConfig.KitItems.tin_can_tripline), 0,
        "the kit is spent")

    local cmd = _findServerCmd("WirePlaced")
    assert_not_nil(cmd, "WirePlaced broadcast should have been sent")
    assert_eq(cmd.args.x, 10)
    assert_eq(cmd.args.ownerId, "alice")
end)

test("no square at those coordinates: no-op", function()
    resetAll()
    local player = _kitted(0, 0, 0, "alice")

    place(player, "tin_can_tripline", 99, 99, 0)

    assert_eq(#_createdWires, 0)
end)

test("no character: no-op rather than an error", function()
    resetAll()
    _makeSquare(10, 20, 0)

    local obj = ISDeadwireTripLine:new("tin_can_tripline", nil)
    obj:create(10, 20, 0, false, obj.sprite)

    assert_eq(#_createdWires, 0, "both engine paths set character; say so if neither did")
end)

test("unknown wire type: no-op", function()
    resetAll()
    _makeSquare(10, 20, 0)
    local player = _kitted(10, 20, 0, "alice")

    place(player, "definitely_not_a_wire", 10, 20, 0)

    assert_eq(#_createdWires, 0)
end)

-- The gates that moved here from the deleted PlaceWire handler (#36).

test("disabled tier: no wire, and the kit survives (#36)", function()
    resetAll()
    SandboxVars.Deadwire.EnableTier0 = false
    _makeSquare(10, 20, 0)
    local player = _kitted(10, 20, 0, "alice")

    place(player, "tin_can_tripline", 10, 20, 0)

    assert_eq(#_createdWires, 0, "a disabled tier must not be placeable")
    assert_eq(_countItems(player, DeadwireConfig.KitItems.tin_can_tripline), 1,
        "and a refused placement costs nothing")
end)

test("EnableMod=false disables every tier: no wire (#36)", function()
    resetAll()
    SandboxVars.Deadwire.EnableMod = false
    _makeSquare(10, 20, 0)
    local player = _kitted(10, 20, 0, "alice")

    place(player, "tin_can_tripline", 10, 20, 0)

    assert_eq(#_createdWires, 0)
end)

test("player already at WireMaxPerPlayer: no wire (#36)", function()
    resetAll()
    SandboxVars.Deadwire.WireMaxPerPlayer = 1
    _makeSquare(1, 1, 0)
    DeadwireNetwork.registerTile(1, 1, 0, 1, "tin_can_tripline", "alice")

    _makeSquare(2, 2, 0)
    local player = _kitted(2, 2, 0, "alice")

    place(player, "tin_can_tripline", 2, 2, 0)

    assert_eq(#_createdWires, 0, "the cap has to live on the path that places wires")
    assert_eq(_countItems(player, DeadwireConfig.KitItems.tin_can_tripline), 1)
end)

test("another player's wires do not count against my cap (#36)", function()
    resetAll()
    SandboxVars.Deadwire.WireMaxPerPlayer = 1
    _makeSquare(1, 1, 0)
    DeadwireNetwork.registerTile(1, 1, 0, 1, "tin_can_tripline", "bob")

    _makeSquare(2, 2, 0)
    local player = _kitted(2, 2, 0, "alice")

    place(player, "tin_can_tripline", 2, 2, 0)

    assert_eq(#_createdWires, 1, "the cap is per player")
end)

test("no kit: no wire", function()
    resetAll()
    _makeSquare(10, 20, 0)
    local player = _mockPlayer(10, 20, 0, "mallory")

    place(player, "tin_can_tripline", 10, 20, 0)

    assert_eq(#_createdWires, 0)
end)

test("holding the wrong kit does not place the wire", function()
    resetAll()
    _makeSquare(10, 20, 0)
    local player = _mockPlayer(10, 20, 0, "mallory")
    _giveItem(player, DeadwireConfig.KitItems.bell_tripline)

    place(player, "tin_can_tripline", 10, 20, 0)

    assert_eq(#_createdWires, 0, "a bell kit must not place a tin can wire")
    assert_eq(_countItems(player, DeadwireConfig.KitItems.bell_tripline), 1)
end)

test("LogWirePlacements=false still places the wire (#36)", function()
    resetAll()
    SandboxVars.Deadwire.LogWirePlacements = false
    _makeSquare(10, 20, 0)
    local player = _kitted(10, 20, 0, "alice")

    place(player, "tin_can_tripline", 10, 20, 0)

    assert_eq(#_createdWires, 1, "the log switch controls logging, nothing else")
end)

-----------------------------------------------------------------
suite("BuildActions: ISDeadwireTripLine:isValid")
-----------------------------------------------------------------

test("an empty, free square is valid", function()
    resetAll()
    local sq = _makeSquare(30, 30, 0)
    local player = _mockPlayer(30, 30, 0, "alice")
    local obj = ISDeadwireTripLine:new("tin_can_tripline", player)

    assert_true(obj:isValid(sq))
end)

test("nil square is not valid", function()
    resetAll()
    local player = _mockPlayer(30, 30, 0, "alice")
    local obj = ISDeadwireTripLine:new("tin_can_tripline", player)

    assert_false(obj:isValid(nil))
end)

test("a square that already holds a wire is not valid", function()
    resetAll()
    local sq = _makeSquare(30, 30, 0)
    DeadwireNetwork.registerTile(30, 30, 0, 1, "tin_can_tripline", "bob")
    local player = _mockPlayer(30, 30, 0, "alice")
    local obj = ISDeadwireTripLine:new("tin_can_tripline", player)

    assert_false(obj:isValid(sq), "wires do not stack")
end)

test("a square with a vehicle on it is not valid", function()
    resetAll()
    local sq = _makeSquare(30, 30, 0)
    sq._vehicleIntersecting = true
    local player = _mockPlayer(30, 30, 0, "alice")
    local obj = ISDeadwireTripLine:new("tin_can_tripline", player)

    assert_false(obj:isValid(sq))
end)

test("a blocked square is not valid", function()
    resetAll()
    local sq = _makeSquare(30, 30, 0)
    sq._freeOrMidair = false
    local player = _mockPlayer(30, 30, 0, "alice")
    local obj = ISDeadwireTripLine:new("tin_can_tripline", player)

    assert_false(obj:isValid(sq))
end)
