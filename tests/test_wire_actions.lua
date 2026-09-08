-- tests/test_wire_actions.lua
-- Tests for ISDeadwireWireAction (client/WireActions.lua).
--
-- The file derives from a vanilla class at file scope, which is the shape that
-- throws at load and silently kills every line below it. Requiring it in
-- run.lua is half the coverage; this is the other half.
--
-- The action exists because the server bounds how far a player may be from a
-- wire (#36) and a context menu opens on any tile on screen. It runs after the
-- walk, so the player is standing next to the wire when the command is sent.

local function resetAll()
    _reset()
    _clearCommands()
end

local function wireAt(x, y, z, wireType, owner)
    _makeSquare(x, y, z)
    DeadwireNetwork.registerTile(x, y, z, 1, wireType, owner)
end

-----------------------------------------------------------------
suite("WireActions: construction")
-----------------------------------------------------------------

test("the action carries the command and the wire's own coordinates", function()
    resetAll()
    local alice = _mockPlayer(1, 1, 0, "alice")

    local action = ISDeadwireWireAction:new(alice, "RemoveWire", 7, 8, 0, 80)

    assert_eq(action.command, "RemoveWire")
    assert_eq(action.wx, 7)
    assert_eq(action.wy, 8)
    assert_eq(action.wz, 0)
    assert_eq(action.character, alice)
end)

test("walking or running cancels it", function()
    resetAll()
    local alice = _mockPlayer(1, 1, 0, "alice")

    local action = ISDeadwireWireAction:new(alice, "RemoveWire", 7, 8, 0, 80)

    assert_true(action.stopOnWalk, "stepping away mid-action has to abort it")
    assert_true(action.stopOnRun)
    assert_true(action.useProgressBar)
end)

test("maxTime is the caller's, not a default", function()
    resetAll()
    local alice = _mockPlayer(1, 1, 0, "alice")

    local remove = ISDeadwireWireAction:new(alice, "RemoveWire", 7, 8, 0, 80)
    local camo   = ISDeadwireWireAction:new(alice, "CamouflageWire", 7, 8, 0, 250)

    assert_eq(remove.maxTime, 80)
    assert_eq(camo.maxTime, 250,
        "the two jobs are meant to take visibly different amounts of time")
end)

-----------------------------------------------------------------
suite("WireActions: isValid")
--
-- The wire has to still be there when the walk finishes. Somebody else's
-- zombie can trip a tin can line and destroy it while the player is walking.
-----------------------------------------------------------------

test("a wire that is still there is valid", function()
    resetAll()
    wireAt(7, 8, 0, "tin_can_tripline", "alice")
    local alice = _mockPlayer(1, 1, 0, "alice")

    local action = ISDeadwireWireAction:new(alice, "RemoveWire", 7, 8, 0, 80)

    assert_true(action:isValid())
end)

test("a wire destroyed during the walk is not valid", function()
    resetAll()
    wireAt(7, 8, 0, "tin_can_tripline", "alice")
    local alice = _mockPlayer(1, 1, 0, "alice")
    local action = ISDeadwireWireAction:new(alice, "RemoveWire", 7, 8, 0, 80)

    DeadwireNetwork.unregisterTile(7, 8, 0)

    assert_false(action:isValid(),
        "a tin can line the walk outlived is the ordinary case, not an edge one")
end)

test("camouflaging a wire somebody camouflaged first is not valid", function()
    resetAll()
    wireAt(7, 8, 0, "tin_can_tripline", "alice")
    local alice = _mockPlayer(1, 1, 0, "alice")
    local action = ISDeadwireWireAction:new(alice, "CamouflageWire", 7, 8, 0, 250)

    DeadwireNetwork.setCamouflaged(7, 8, 0, true, 100)

    assert_false(action:isValid())
end)

test("removing an already camouflaged wire is still valid", function()
    resetAll()
    wireAt(7, 8, 0, "tin_can_tripline", "alice")
    DeadwireNetwork.setCamouflaged(7, 8, 0, true, 100)
    local alice = _mockPlayer(1, 1, 0, "alice")

    local action = ISDeadwireWireAction:new(alice, "RemoveWire", 7, 8, 0, 80)

    assert_true(action:isValid(),
        "the camo check belongs to CamouflageWire alone; refusing removal "
        .. "would strand the wire")
end)

-----------------------------------------------------------------
suite("WireActions: perform")
-----------------------------------------------------------------

test("perform sends the command it was built with", function()
    resetAll()
    wireAt(7, 8, 0, "tin_can_tripline", "alice")
    local alice = _mockPlayer(1, 1, 0, "alice")
    local action = ISDeadwireWireAction:new(alice, "RemoveWire", 7, 8, 0, 80)

    action:perform()

    assert_eq(#_sentClient, 1)
    assert_eq(_sentClient[1].mod, DeadwireConfig.MODULE)
    assert_eq(_sentClient[1].cmd, "RemoveWire")
    assert_eq(_sentClient[1].args.x, 7)
    assert_eq(_sentClient[1].args.y, 8)
    assert_eq(_sentClient[1].args.z, 0)
end)

test("camouflage perform sends CamouflageWire, not RemoveWire", function()
    resetAll()
    wireAt(7, 8, 0, "tin_can_tripline", "alice")
    local alice = _mockPlayer(1, 1, 0, "alice")
    local action = ISDeadwireWireAction:new(alice, "CamouflageWire", 7, 8, 0, 250)

    action:perform()

    assert_eq(_sentClient[1].cmd, "CamouflageWire")
end)

test("perform still finishes the base action", function()
    resetAll()
    wireAt(7, 8, 0, "tin_can_tripline", "alice")
    local alice = _mockPlayer(1, 1, 0, "alice")
    local action = ISDeadwireWireAction:new(alice, "RemoveWire", 7, 8, 0, 80)

    action:perform()

    assert_true(action._performed,
        "skipping the base call leaves the action queue stuck on this entry")
end)

test("the client sends no authority, only a request", function()
    resetAll()
    wireAt(7, 8, 0, "tin_can_tripline", "alice")
    local alice = _mockPlayer(1, 1, 0, "alice")
    local action = ISDeadwireWireAction:new(alice, "RemoveWire", 7, 8, 0, 80)

    action:perform()

    assert_nil(_sentClient[1].args.ownerId,
        "ownership is the server's to decide; sending it would invite a "
        .. "modified client to claim someone else's wire")
    assert_eq(#_sentServer, 0)
end)

-----------------------------------------------------------------
suite("WireActions: animation and facing")
-----------------------------------------------------------------

test("update turns the player toward the wire", function()
    resetAll()
    wireAt(7, 8, 0, "tin_can_tripline", "alice")
    local alice = _mockPlayer(1, 1, 0, "alice")
    local action = ISDeadwireWireAction:new(alice, "RemoveWire", 7, 8, 0, 80)

    action:update()

    assert_not_nil(alice._facing)
    assert_eq(alice._facing.x, 7)
    assert_eq(alice._facing.y, 8)
end)

test("start plays the loot animation", function()
    resetAll()
    local alice = _mockPlayer(1, 1, 0, "alice")
    local action = ISDeadwireWireAction:new(alice, "RemoveWire", 7, 8, 0, 80)

    action:start()

    assert_eq(action._anim, "Loot")
end)

test("stop reaches the base class", function()
    resetAll()
    local alice = _mockPlayer(1, 1, 0, "alice")
    local action = ISDeadwireWireAction:new(alice, "RemoveWire", 7, 8, 0, 80)

    action:stop()

    assert_true(action._stopped)
    assert_eq(#_sentClient, 0, "an aborted action must not send its command")
end)
