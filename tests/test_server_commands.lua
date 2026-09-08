-- tests/test_server_commands.lua
-- Tests for ServerCommands.lua handlers (invoked via Events.OnClientCommand:Fire)
-- Modules are already require'd by run.lua. Stubs are already loaded.
--
-- WireManager is replaced with a lightweight mock so tests do not need a real
-- PZ world. The mock registers tiles into WireNetwork so downstream checks
-- (e.g. "tile already occupied") work correctly.

-----------------------------------------------------------------
-- WireManager mock (applied once, reset between tests)
-----------------------------------------------------------------
local _createdWires = {}
local _destroyedWires = {}

DeadwireWireManager.createWire = function(sq, wireType, ownerId, networkId)
    table.insert(_createdWires, { sq = sq, wireType = wireType, ownerId = ownerId, networkId = networkId })
    -- Register in WireNetwork so PlaceWire's duplicate-check sees it as placed
    local x, y, z = sq:getX(), sq:getY(), sq:getZ()
    DeadwireNetwork.registerTile(x, y, z, networkId, wireType, ownerId)
    return { _fake = true }   -- non-nil = success
end

DeadwireWireManager.destroyWire = function(x, y, z)
    table.insert(_destroyedWires, { x = x, y = y, z = z })
    DeadwireNetwork.unregisterTile(x, y, z)
    return true
end

-- Helper: full reset between tests
local function resetAll()
    _reset()          -- clears network, squares, commands, sandbox, world age
    _createdWires  = {}
    _destroyedWires = {}
    _clearCommands()
end

-----------------------------------------------------------------
-- PlaceWire is gone (#36)
--
-- It was a second placement path that trusted the coordinates it was handed,
-- and nothing in the mod ever called it. Its tier gate, wire cap and kit check
-- moved to ISDeadwireTripLine:create, which is the path the engine actually
-- uses; see tests/test_build_actions.lua. This one test is what stops it
-- coming back unnoticed.
-----------------------------------------------------------------
suite("ServerCommands: PlaceWire is not a command")

test("a PlaceWire command is ignored, whatever it asks for", function()
    resetAll()
    local sq = _makeSquare(10, 20, 0)
    local player = _mockPlayer(10, 20, 0, "mallory")
    _giveItem(player, DeadwireConfig.KitItems.tin_can_tripline)

    Events.OnClientCommand:Fire("Deadwire", "PlaceWire", player, {
        x = 10, y = 20, z = 0, wireType = "tin_can_tripline"
    })

    assert_eq(#_createdWires, 0, "there must be no PlaceWire handler")
    assert_nil(_findServerCmd("WirePlaced"), "and nothing broadcast")
end)

-----------------------------------------------------------------
-- RemoveWire tests
-----------------------------------------------------------------
suite("ServerCommands: RemoveWire")

test("owner removes own wire: destroyWire called, WireDestroyed sent", function()
    resetAll()
    local sq = _makeSquare(5, 5, 0)
    DeadwireNetwork.registerTile(5, 5, 0, 1, "tin_can_tripline", "alice")

    local player = _mockPlayer(5, 5, 0, "alice")

    Events.OnClientCommand:Fire("Deadwire", "RemoveWire", player, {
        x = 5, y = 5, z = 0
    })

    assert_eq(#_destroyedWires, 1, "destroyWire should have been called")
    assert_eq(_destroyedWires[1].x, 5)
    assert_eq(_destroyedWires[1].y, 5)
    assert_eq(_destroyedWires[1].z, 0)

    local cmd = _findServerCmd("WireDestroyed")
    assert_not_nil(cmd, "WireDestroyed broadcast should have been sent")
    assert_eq(cmd.args.x, 5)
    assert_eq(cmd.args.y, 5)
    assert_eq(cmd.args.z, 0)
end)

test("non-owner, non-admin cannot remove wire: no-op", function()
    resetAll()
    local sq = _makeSquare(5, 5, 0)
    DeadwireNetwork.registerTile(5, 5, 0, 1, "tin_can_tripline", "alice")

    local player = _mockPlayer(5, 5, 0, "bob")  -- not the owner, not admin

    Events.OnClientCommand:Fire("Deadwire", "RemoveWire", player, {
        x = 5, y = 5, z = 0
    })

    assert_eq(#_destroyedWires, 0, "non-owner should not be able to remove wire")
    assert_nil(_findServerCmd("WireDestroyed"))
end)

-- #14: the old check called Capability.CanBuildAnywhere, which does not exist
-- in 42.20, and called it on getRole() without a nil guard.

test("non-owner with no role is denied, not an error (#14)", function()
    resetAll()
    local sq = _makeSquare(5, 5, 0)
    DeadwireNetwork.registerTile(5, 5, 0, 1, "tin_can_tripline", "alice")

    local player = _mockRolelessPlayer(5, 5, 0, "bob")

    Events.OnClientCommand:Fire("Deadwire", "RemoveWire", player, {
        x = 5, y = 5, z = 0
    })

    assert_eq(#_destroyedWires, 0, "roleless non-owner must be denied")
end)

test("owner with no role can still remove their own wire (#14)", function()
    resetAll()
    local sq = _makeSquare(5, 5, 0)
    DeadwireNetwork.registerTile(5, 5, 0, 1, "tin_can_tripline", "alice")

    local player = _mockRolelessPlayer(5, 5, 0, "alice")

    Events.OnClientCommand:Fire("Deadwire", "RemoveWire", player, {
        x = 5, y = 5, z = 0
    })

    assert_eq(#_destroyedWires, 1, "ownership must not depend on having a role")
end)

test("admin removes any wire: destroyWire called", function()
    resetAll()
    local sq = _makeSquare(5, 5, 0)
    DeadwireNetwork.registerTile(5, 5, 0, 1, "tin_can_tripline", "alice")

    local admin = _mockAdmin(5, 5, 0, "serverop")

    Events.OnClientCommand:Fire("Deadwire", "RemoveWire", admin, {
        x = 5, y = 5, z = 0
    })

    assert_eq(#_destroyedWires, 1, "admin should be able to remove any wire")
    assert_not_nil(_findServerCmd("WireDestroyed"))
end)

-- #36: RemoveWire enforced ownership but had no distance bound at all, so an
-- owner could unmake their whole perimeter from across the loaded map. The
-- context menu walks the player to the wire first, so the bound is reachable.

test("owner too far away cannot remove their own wire (#36)", function()
    resetAll()
    _makeSquare(5, 5, 0)
    _makeSquare(40, 5, 0)          -- a real square, so this fails on distance
    DeadwireNetwork.registerTile(5, 5, 0, 1, "tin_can_tripline", "alice")

    local player = _mockPlayer(40, 5, 0, "alice")

    Events.OnClientCommand:Fire("Deadwire", "RemoveWire", player, {
        x = 5, y = 5, z = 0
    })

    assert_eq(#_destroyedWires, 0, "35 tiles away is not arm's reach")
    assert_nil(_findServerCmd("WireDestroyed"))
end)

test("standing next to the wire is close enough (#36)", function()
    resetAll()
    _makeSquare(5, 5, 0)
    _makeSquare(6, 5, 0)
    DeadwireNetwork.registerTile(5, 5, 0, 1, "tin_can_tripline", "alice")

    local player = _mockPlayer(6, 5, 0, "alice")

    Events.OnClientCommand:Fire("Deadwire", "RemoveWire", player, {
        x = 5, y = 5, z = 0
    })

    assert_eq(#_destroyedWires, 1, "an adjacent owner must still be able to remove")
end)

test("a wire on the floor below is not in reach (#36)", function()
    resetAll()
    _makeSquare(5, 5, 0)
    _makeSquare(5, 5, 1)
    DeadwireNetwork.registerTile(5, 5, 0, 1, "tin_can_tripline", "alice")

    local player = _mockPlayer(5, 5, 1, "alice")

    Events.OnClientCommand:Fire("Deadwire", "RemoveWire", player, {
        x = 5, y = 5, z = 0
    })

    assert_eq(#_destroyedWires, 0, "same column, wrong storey")
end)

test("an admin still cannot remove a wire from across the map (#36)", function()
    resetAll()
    _makeSquare(5, 5, 0)
    _makeSquare(40, 5, 0)
    DeadwireNetwork.registerTile(5, 5, 0, 1, "tin_can_tripline", "alice")

    local admin = _mockAdmin(40, 5, 0, "serverop")

    Events.OnClientCommand:Fire("Deadwire", "RemoveWire", admin, {
        x = 5, y = 5, z = 0
    })

    assert_eq(#_destroyedWires, 0, "admin bypasses ownership, not physics")
end)

test("no wire at position: no-op", function()
    resetAll()
    local sq = _makeSquare(5, 5, 0)
    -- No wire registered

    local player = _mockPlayer(5, 5, 0, "alice")

    Events.OnClientCommand:Fire("Deadwire", "RemoveWire", player, {
        x = 5, y = 5, z = 0
    })

    assert_eq(#_destroyedWires, 0, "destroyWire should NOT be called when no wire exists")
    assert_nil(_findServerCmd("WireDestroyed"))
end)

-----------------------------------------------------------------
-- WireTriggered tests
-----------------------------------------------------------------
suite("ServerCommands: WireTriggered")

test("tin_can (breakOnTrigger=true): destroyWire called, WireDestroyed sent", function()
    resetAll()
    local sq = _makeSquare(6, 6, 0)
    DeadwireNetwork.registerTile(6, 6, 0, 1, "tin_can_tripline", "alice")
    _mockZombie(6, 6, 0)   -- something is actually on the wire (#31)

    local player = _mockPlayer(6, 6, 0, "bob")

    Events.OnClientCommand:Fire("Deadwire", "WireTriggered", player, {
        x = 6, y = 6, z = 0, wireType = "tin_can_tripline"
    })

    assert_eq(#_destroyedWires, 1, "tin_can wire should be destroyed after trigger")
    assert_not_nil(_findServerCmd("WireDestroyed"), "WireDestroyed should be broadcast")

    -- WireTriggered sound command should also be sent
    local trigCmd = _findServerCmd("WireTriggered")
    assert_not_nil(trigCmd, "WireTriggered sound broadcast should be sent")
    assert_eq(trigCmd.args.x, 6)
    assert_eq(trigCmd.args.y, 6)
    assert_eq(trigCmd.args.z, 0)
    assert_not_nil(trigCmd.args.soundName)
end)

test("reinforced (breakOnTrigger=false): no destroy, cooldown set, WireTriggered sound sent", function()
    resetAll()
    local sq = _makeSquare(7, 7, 0)
    DeadwireNetwork.registerTile(7, 7, 0, 1, "reinforced_tripline", "alice")
    _mockZombie(7, 7, 0)   -- something is actually on the wire (#31)

    _setOsTime(1000)
    local player = _mockPlayer(7, 7, 0, "bob")

    Events.OnClientCommand:Fire("Deadwire", "WireTriggered", player, {
        x = 7, y = 7, z = 0, wireType = "reinforced_tripline"
    })

    assert_eq(#_destroyedWires, 0, "reinforced wire should NOT be destroyed on trigger")
    assert_nil(_findServerCmd("WireDestroyed"), "WireDestroyed should NOT be sent")

    -- Cooldown should now be active
    assert_true(DeadwireNetwork.isOnCooldown(7, 7, 0), "cooldown should be set after trigger")

    local trigCmd = _findServerCmd("WireTriggered")
    assert_not_nil(trigCmd, "WireTriggered sound broadcast should be sent")
    assert_eq(trigCmd.args.soundName, DeadwireConfig.Sounds.WIRE_RATTLE)

    -- Clients run detection against their own copy of the network, so the
    -- cooldown has to travel with the broadcast or it only exists server-side.
    assert_eq(trigCmd.args.cooldownSeconds,
        DeadwireConfig.WireDefaults.reinforced_tripline.cooldownSeconds,
        "broadcast must carry the cooldown duration for clients to mirror")
end)

test("TinCanBreakOnTrigger=false makes tin can reusable end to end", function()
    resetAll()
    SandboxVars.Deadwire.TinCanBreakOnTrigger = false
    _setOsTime(1000)
    local sq = _makeSquare(6, 6, 0)
    DeadwireNetwork.registerTile(6, 6, 0, 1, "tin_can_tripline", "alice")
    _mockZombie(6, 6, 0)   -- something is actually on the wire (#31)

    local player = _mockPlayer(6, 6, 0, "bob")

    Events.OnClientCommand:Fire("Deadwire", "WireTriggered", player, {
        x = 6, y = 6, z = 0, wireType = "tin_can_tripline"
    })

    assert_eq(#_destroyedWires, 0, "tin can should survive when the option is off")
    assert_true(DeadwireNetwork.isOnCooldown(6, 6, 0),
        "a now-reusable tin can must get a cooldown instead")
end)

-- #31: the server cannot observe a trigger -- detection has to be client-side --
-- so it re-derives the fact instead of trusting the reporter, by looking for a
-- zombie or player on the wire square or one of its 8 neighbours.
--
-- The four tests these replace asserted the bug: they measured how far away the
-- REPORTING player was, which is why trip lines only fired when somebody was
-- already standing next to them. Reporter distance is now only a 100-tile
-- sanity bound, and honest reports from across the map are accepted.

test("distant reporter is accepted when a zombie is on the wire (#31)", function()
    resetAll()
    _makeSquare(6, 6, 0)
    _makeSquare(60, 60, 0)
    DeadwireNetwork.registerTile(6, 6, 0, 1, "tin_can_tripline", "alice")
    _mockZombie(6, 6, 0)

    -- 54 tiles away: nowhere near the wire, and exactly the case the old gate
    -- threw away. This is the whole feature.
    local bob = _mockPlayer(60, 60, 0, "bob")

    Events.OnClientCommand:Fire("Deadwire", "WireTriggered", bob, {
        x = 6, y = 6, z = 0, wireType = "tin_can_tripline"
    })

    assert_eq(#_destroyedWires, 1, "a wire tripped far from any player must still fire")
    assert_not_nil(_findServerCmd("WireDestroyed"))
    assert_not_nil(_findServerCmd("WireTriggered"))
end)

test("report is rejected when nothing is near the wire (#31)", function()
    resetAll()
    _makeSquare(6, 6, 0)
    _makeSquare(20, 20, 0)
    DeadwireNetwork.registerTile(6, 6, 0, 1, "tin_can_tripline", "alice")

    -- Well inside the sanity bound, so only the entity check can reject this.
    local mallory = _mockPlayer(20, 20, 0, "mallory")

    Events.OnClientCommand:Fire("Deadwire", "WireTriggered", mallory, {
        x = 6, y = 6, z = 0, wireType = "tin_can_tripline"
    })

    assert_eq(#_destroyedWires, 0, "an empty tile cannot have been tripped")
    assert_nil(_findServerCmd("WireDestroyed"))
    assert_nil(_findServerCmd("WireTriggered"))
end)

test("a zombie on a neighbouring tile is accepted (#31)", function()
    resetAll()
    _makeSquare(6, 6, 0)
    _makeSquare(7, 7, 0)
    _makeSquare(20, 20, 0)
    DeadwireNetwork.registerTile(6, 6, 0, 1, "tin_can_tripline", "alice")
    _mockZombie(7, 7, 0)   -- diagonal neighbour: absorbs a tick of position lag

    local bob = _mockPlayer(20, 20, 0, "bob")

    Events.OnClientCommand:Fire("Deadwire", "WireTriggered", bob, {
        x = 6, y = 6, z = 0, wireType = "tin_can_tripline"
    })

    assert_eq(#_destroyedWires, 1, "the 3x3 must include diagonals")
end)

test("a zombie two tiles away is not close enough (#31)", function()
    resetAll()
    _makeSquare(6, 6, 0)
    _makeSquare(8, 6, 0)
    _makeSquare(20, 20, 0)
    DeadwireNetwork.registerTile(6, 6, 0, 1, "tin_can_tripline", "alice")
    _mockZombie(8, 6, 0)   -- one tile outside the 3x3

    local bob = _mockPlayer(20, 20, 0, "bob")

    Events.OnClientCommand:Fire("Deadwire", "WireTriggered", bob, {
        x = 6, y = 6, z = 0, wireType = "tin_can_tripline"
    })

    assert_eq(#_destroyedWires, 0, "the scan is 3x3, not a general proximity check")
end)

test("a zombie on the floor above does not trip the wire below (#31)", function()
    resetAll()
    _makeSquare(6, 6, 0)
    _makeSquare(6, 6, 1)
    _makeSquare(20, 20, 0)
    DeadwireNetwork.registerTile(6, 6, 0, 1, "tin_can_tripline", "alice")
    _mockZombie(6, 6, 1)   -- directly above the wire

    local bob = _mockPlayer(20, 20, 0, "bob")

    Events.OnClientCommand:Fire("Deadwire", "WireTriggered", bob, {
        x = 6, y = 6, z = 0, wireType = "tin_can_tripline"
    })

    assert_eq(#_destroyedWires, 0, "z is an exact match, not part of the 3x3")
end)

test("reporter beyond the sanity bound is rejected even with a zombie there (#31)", function()
    resetAll()
    _makeSquare(6, 6, 0)
    _makeSquare(600, 600, 0)
    DeadwireNetwork.registerTile(6, 6, 0, 1, "tin_can_tripline", "alice")
    _mockZombie(6, 6, 0)   -- the trip is real, but this reporter cannot know it

    local mallory = _mockPlayer(600, 600, 0, "mallory")

    Events.OnClientCommand:Fire("Deadwire", "WireTriggered", mallory, {
        x = 6, y = 6, z = 0, wireType = "tin_can_tripline"
    })

    assert_eq(#_destroyedWires, 0, "594 tiles is past the 100-tile sanity bound")
end)

test("camo is not degraded by a report with nothing near the wire (#31)", function()
    resetAll()
    _makeSquare(6, 6, 0)
    _makeSquare(20, 20, 0)
    DeadwireNetwork.registerTile(6, 6, 0, 1, "reinforced_tripline", "alice")
    DeadwireNetwork.setCamouflaged(6, 6, 0, true, 100)
    SandboxVars.Deadwire.CamoTriggerDegrade = 15

    local mallory = _mockPlayer(20, 20, 0, "mallory")

    Events.OnClientCommand:Fire("Deadwire", "WireTriggered", mallory, {
        x = 6, y = 6, z = 0, wireType = "reinforced_tripline"
    })

    assert_eq(DeadwireNetwork.getTile(6, 6, 0).camoDurability, 100,
        "invented reports must not burn down camouflage")
end)

test("wire with camo (durability=100, degrade=15): durability reduced to 85, no WireCamouflaged", function()
    resetAll()
    local sq = _makeSquare(8, 8, 0)
    DeadwireNetwork.registerTile(8, 8, 0, 1, "reinforced_tripline", "alice")
    DeadwireNetwork.setCamouflaged(8, 8, 0, true, 100)
    SandboxVars.Deadwire.CamoTriggerDegrade = 15
    _mockZombie(8, 8, 0)   -- something is actually on the wire (#31)

    local player = _mockPlayer(8, 8, 0, "bob")

    Events.OnClientCommand:Fire("Deadwire", "WireTriggered", player, {
        x = 8, y = 8, z = 0, wireType = "reinforced_tripline"
    })

    local wire = DeadwireNetwork.getTile(8, 8, 0)
    assert_not_nil(wire, "wire should still exist")
    assert_eq(wire.camoDurability, 85, "camo durability should be 85 after 15-point degrade")
    assert_true(wire.camouflaged, "wire should still be camouflaged")
    assert_nil(_findServerCmd("WireCamouflaged"), "WireCamouflaged should NOT be sent (camo not removed)")
end)

test("wire with camo at durability=10 (degrade=15 -> <=0): camo removed, WireCamouflaged sent", function()
    resetAll()
    local sq = _makeSquare(9, 9, 0)
    DeadwireNetwork.registerTile(9, 9, 0, 1, "reinforced_tripline", "alice")
    DeadwireNetwork.setCamouflaged(9, 9, 0, true, 10)
    SandboxVars.Deadwire.CamoTriggerDegrade = 15
    _mockZombie(9, 9, 0)   -- something is actually on the wire (#31)

    local player = _mockPlayer(9, 9, 0, "bob")

    Events.OnClientCommand:Fire("Deadwire", "WireTriggered", player, {
        x = 9, y = 9, z = 0, wireType = "reinforced_tripline"
    })

    local wire = DeadwireNetwork.getTile(9, 9, 0)
    assert_not_nil(wire, "wire should still exist (reinforced doesn't break)")
    assert_false(wire.camouflaged, "camo should be removed when durability hits zero")

    local camoCmd = _findServerCmd("WireCamouflaged")
    assert_not_nil(camoCmd, "WireCamouflaged broadcast should be sent when camo is stripped")
    assert_false(camoCmd.args.camouflaged, "broadcast should indicate camouflaged=false")
    assert_eq(camoCmd.args.durability, 0)
    assert_eq(camoCmd.args.x, 9)
    assert_eq(camoCmd.args.y, 9)
    assert_eq(camoCmd.args.z, 0)
end)

-- #37: cooldownSeconds is declared per wire type. There is no `or 36` fallback,
-- because that is how tanglefoot came to inherit the Tier 1 trip line cooldown
-- and give a whole horde one 40 percent roll per tile per 36 real seconds.

test("tanglefoot gets no cooldown (#37)", function()
    resetAll()
    _setOsTime(1000)
    _makeSquare(14, 14, 0)
    DeadwireNetwork.registerTile(14, 14, 0, 1, "tanglefoot", "alice")
    _mockZombie(14, 14, 0)

    local bob = _mockPlayer(14, 14, 0, "bob")

    Events.OnClientCommand:Fire("Deadwire", "WireTriggered", bob, {
        x = 14, y = 14, z = 0, wireType = "tanglefoot"
    })

    assert_false(DeadwireNetwork.isOnCooldown(14, 14, 0),
        "every zombie entering a tanglefoot tile gets its own roll")
    assert_eq(#_destroyedWires, 0, "and tanglefoot does not break")
end)

test("a type declaring no cooldownSeconds borrows nobody else's (#37)", function()
    resetAll()
    _setOsTime(1000)
    _makeSquare(15, 15, 0)
    DeadwireNetwork.registerTile(15, 15, 0, 1, "reinforced_tripline", "alice")
    _mockZombie(15, 15, 0)

    -- Stand in for a wire type someone adds and forgets to give a cooldown.
    local saved = DeadwireConfig.WireDefaults.reinforced_tripline.cooldownSeconds
    DeadwireConfig.WireDefaults.reinforced_tripline.cooldownSeconds = nil

    local bob = _mockPlayer(15, 15, 0, "bob")
    Events.OnClientCommand:Fire("Deadwire", "WireTriggered", bob, {
        x = 15, y = 15, z = 0, wireType = "reinforced_tripline"
    })

    DeadwireConfig.WireDefaults.reinforced_tripline.cooldownSeconds = saved

    assert_false(DeadwireNetwork.isOnCooldown(15, 15, 0),
        "a missing value must log, not silently become 36")
end)

-----------------------------------------------------------------
-- RequestWireSync tests (#33)
--
-- This replaces a hook on Events.OnPlayerConnect, which does not exist in
-- 42.20.4 and threw at load in every run mode, so the join sync never ran once.
-- 159 tests passed over it because the Events stub invented any name asked for.
-----------------------------------------------------------------
suite("ServerCommands: RequestWireSync")

test("a joining client is answered with the wire list, addressed to them", function()
    resetAll()
    DeadwireWireManager.saveWire(3, 3, 0, 1, "tin_can_tripline", "alice")
    DeadwireWireManager.saveWire(4, 4, 0, 2, "bell_tripline", "alice")

    _makeSquare(50, 50, 0)
    local bob = _mockPlayer(50, 50, 0, "bob")

    Events.OnClientCommand:Fire("Deadwire", "RequestWireSync", bob, {})

    local cmd = _findServerCmd("WireNetworkSync")
    assert_not_nil(cmd, "the server must answer a sync request")
    assert_eq(cmd.target, bob, "the reply goes to the requesting player, not everyone")
    assert_eq(#cmd.args.wires, 2, "both saved wires should be sent")
end)

test("camouflage travels with the sync so a joining client hides the wire", function()
    resetAll()
    DeadwireWireManager.saveWire(3, 3, 0, 1, "tin_can_tripline", "alice")
    DeadwireWireManager.saveCamo(3, 3, 0, true, 40)

    _makeSquare(50, 50, 0)
    local bob = _mockPlayer(50, 50, 0, "bob")

    Events.OnClientCommand:Fire("Deadwire", "RequestWireSync", bob, {})

    local cmd = _findServerCmd("WireNetworkSync")
    assert_not_nil(cmd)
    assert_true(cmd.args.wires[1].camouflaged, "camo state must reach the joining client (#34)")
    assert_eq(cmd.args.wires[1].camoDurability, 40)
end)

-----------------------------------------------------------------
-- CamouflageWire tests
-----------------------------------------------------------------
suite("ServerCommands: CamouflageWire")

test("valid uncamouflaged wire: camo set, WireCamouflaged sent", function()
    resetAll()
    local sq = _makeSquare(11, 11, 0)
    DeadwireNetwork.registerTile(11, 11, 0, 1, "tin_can_tripline", "alice")
    SandboxVars.Deadwire.EnableCamouflage = true
    SandboxVars.Deadwire.CamoMaxDurability = 100

    local player = _mockPlayer(11, 11, 0, "alice")

    Events.OnClientCommand:Fire("Deadwire", "CamouflageWire", player, {
        x = 11, y = 11, z = 0
    })

    local wire = DeadwireNetwork.getTile(11, 11, 0)
    assert_not_nil(wire, "wire should still exist")
    assert_true(wire.camouflaged, "wire should be marked camouflaged")
    assert_eq(wire.camoDurability, 100)

    local cmd = _findServerCmd("WireCamouflaged")
    assert_not_nil(cmd, "WireCamouflaged broadcast should be sent")
    assert_true(cmd.args.camouflaged)
    assert_eq(cmd.args.durability, 100)
    assert_eq(cmd.args.x, 11)
    assert_eq(cmd.args.y, 11)
    assert_eq(cmd.args.z, 0)
end)

test("wire already camouflaged: no-op, WireCamouflaged NOT sent again", function()
    resetAll()
    local sq = _makeSquare(12, 12, 0)
    DeadwireNetwork.registerTile(12, 12, 0, 1, "tin_can_tripline", "alice")
    DeadwireNetwork.setCamouflaged(12, 12, 0, true, 100)
    SandboxVars.Deadwire.EnableCamouflage = true

    local player = _mockPlayer(12, 12, 0, "alice")

    Events.OnClientCommand:Fire("Deadwire", "CamouflageWire", player, {
        x = 12, y = 12, z = 0
    })

    assert_nil(_findServerCmd("WireCamouflaged"),
        "WireCamouflaged should NOT be sent when wire is already camouflaged")
end)

test("EnableCamouflage=false: no-op", function()
    resetAll()
    local sq = _makeSquare(13, 13, 0)
    DeadwireNetwork.registerTile(13, 13, 0, 1, "tin_can_tripline", "alice")
    SandboxVars.Deadwire.EnableCamouflage = false

    local player = _mockPlayer(13, 13, 0, "alice")

    Events.OnClientCommand:Fire("Deadwire", "CamouflageWire", player, {
        x = 13, y = 13, z = 0
    })

    local wire = DeadwireNetwork.getTile(13, 13, 0)
    assert_false(wire.camouflaged, "wire should NOT be camouflaged when EnableCamouflage=false")
    assert_nil(_findServerCmd("WireCamouflaged"), "WireCamouflaged should NOT be sent")
end)

-- #36: this handler had no owner check, no distance check and no material
-- check. Camouflaging somebody else's wire changes their perimeter as much as
-- removing it does, so it gets the same authority as RemoveWire.

test("non-owner, non-admin cannot camouflage another player's wire (#36)", function()
    resetAll()
    _makeSquare(14, 14, 0)
    DeadwireNetwork.registerTile(14, 14, 0, 1, "tin_can_tripline", "alice")
    SandboxVars.Deadwire.EnableCamouflage = true

    local player = _mockPlayer(14, 14, 0, "bob")

    Events.OnClientCommand:Fire("Deadwire", "CamouflageWire", player, {
        x = 14, y = 14, z = 0
    })

    assert_false(DeadwireNetwork.getTile(14, 14, 0).camouflaged,
        "bob must not be able to hide alice's wire")
    assert_nil(_findServerCmd("WireCamouflaged"))
end)

test("an admin can camouflage any wire (#36)", function()
    resetAll()
    _makeSquare(15, 15, 0)
    DeadwireNetwork.registerTile(15, 15, 0, 1, "tin_can_tripline", "alice")
    SandboxVars.Deadwire.EnableCamouflage = true

    local admin = _mockAdmin(15, 15, 0, "serverop")

    Events.OnClientCommand:Fire("Deadwire", "CamouflageWire", admin, {
        x = 15, y = 15, z = 0
    })

    assert_true(DeadwireNetwork.getTile(15, 15, 0).camouflaged)
    assert_not_nil(_findServerCmd("WireCamouflaged"))
end)

test("owner too far away cannot camouflage their own wire (#36)", function()
    resetAll()
    _makeSquare(16, 16, 0)
    _makeSquare(50, 16, 0)
    DeadwireNetwork.registerTile(16, 16, 0, 1, "tin_can_tripline", "alice")
    SandboxVars.Deadwire.EnableCamouflage = true

    local player = _mockPlayer(50, 16, 0, "alice")

    Events.OnClientCommand:Fire("Deadwire", "CamouflageWire", player, {
        x = 16, y = 16, z = 0
    })

    assert_false(DeadwireNetwork.getTile(16, 16, 0).camouflaged,
        "camouflage is something you do standing over the wire")
    assert_nil(_findServerCmd("WireCamouflaged"))
end)
