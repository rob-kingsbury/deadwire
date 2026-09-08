-- tests/test_camo_visibility.lua
-- Tests for the per-client alpha and outline pass (client/CamoVisibility.lua).
--
-- Written in Session 22 and never executed outside a running game until #47.
-- Both jobs here are visual-only and per-client, so nothing in this file can
-- desync anything -- which also means nothing in it can be caught by a server
-- test. The failure mode is a camouflaged wire that is fully visible, or an
-- owner who cannot find their own perimeter, and both look like "it works" from
-- any angle except the screen.

-- Firing exactly 60 ticks always produces exactly one update, whatever the
-- module's counter happened to be sitting at: the tick that reaches 60 fires
-- and resets to 0, and the remainder cannot reach 60 again.
local function tick(n)
    for _ = 1, (n or 60) do Events.OnTick:Fire() end
end

local function resetAll()
    _reset()
    _clearCommands()
end

-- A wire with its IsoThumpable already linked, which is the normal state once
-- the chunk is loaded.
local function wireAt(x, y, z, wireType, owner)
    local sq = _makeSquare(x, y, z)
    DeadwireNetwork.registerTile(x, y, z, 1, wireType, owner)
    local obj = IsoThumpable.new(getCell(), sq, "deadwire_01_8", false, {})
    DeadwireNetwork.setIsoObject(x, y, z, obj)
    return obj
end

-- The viewer, standing at 0,0,0 unless a test moves them.
local function viewer(username, skill)
    local player = _mockPlayer(0, 0, 0, username)
    if skill then _setPerk(player, Perks.PlantScavenging, skill) end
    _setLocalPlayer(player)
    return player
end

-----------------------------------------------------------------
suite("CamoVisibility: the throttle")
-----------------------------------------------------------------

test("the update runs once per 60 ticks, not every tick", function()
    resetAll()
    local obj = wireAt(3, 0, 0, "tin_can_tripline", "alice")
    DeadwireNetwork.setCamouflaged(3, 0, 0, true, 100)
    viewer("stranger", 0)

    tick(60)                      -- one update, counter now at 0
    assert_eq(obj._alpha, 0.0, "a level 0 stranger should see nothing")

    obj._alpha = 0.777            -- sentinel: only an update overwrites this
    tick(59)
    assert_eq(obj._alpha, 0.777,
        "59 ticks must not reach the update; this pass walks every wire on "
        .. "the map and running it per frame is the cost this throttle avoids")

    tick(1)
    assert_eq(obj._alpha, 0.0, "the 60th tick does the work")
end)

-----------------------------------------------------------------
suite("CamoVisibility: alpha on a camouflaged wire")
-----------------------------------------------------------------

test("the owner sees their own camouflaged wire at full alpha", function()
    resetAll()
    local obj = wireAt(3, 0, 0, "tin_can_tripline", "alice")
    DeadwireNetwork.setCamouflaged(3, 0, 0, true, 100)
    viewer("alice", 0)

    tick()

    assert_eq(obj._alpha, 1.0,
        "you know where you put your own trap; hiding it from the owner is "
        .. "just a way to lose a base to your own wire")
end)

test("CamoVisibleToOwner=false hides it from the owner too", function()
    resetAll()
    SandboxVars.Deadwire.CamoVisibleToOwner = false
    local obj = wireAt(3, 0, 0, "tin_can_tripline", "alice")
    DeadwireNetwork.setCamouflaged(3, 0, 0, true, 100)
    viewer("alice", 0)

    tick()

    assert_eq(obj._alpha, 0.0)
end)

test("a level 0 stranger sees nothing at any range", function()
    resetAll()
    local obj = wireAt(1, 0, 0, "tin_can_tripline", "alice")
    DeadwireNetwork.setCamouflaged(1, 0, 0, true, 100)
    viewer("bob", 0)

    tick()

    assert_eq(obj._alpha, 0.0)
end)

test("level 3 within 3 tiles gets the faint shimmer", function()
    resetAll()
    local obj = wireAt(2, 0, 0, "tin_can_tripline", "alice")
    DeadwireNetwork.setCamouflaged(2, 0, 0, true, 100)
    viewer("bob", 3)

    tick()

    assert_eq(obj._alpha, 0.15)
end)

test("level 3 beyond 3 tiles still sees nothing", function()
    resetAll()
    local obj = wireAt(9, 0, 0, "tin_can_tripline", "alice")
    DeadwireNetwork.setCamouflaged(9, 0, 0, true, 100)
    viewer("bob", 3)

    tick()

    assert_eq(obj._alpha, 0.0,
        "the skill thresholds and the range thresholds are two gates, not one")
end)

test("level 5 within 8 tiles is semi-visible", function()
    resetAll()
    local obj = wireAt(7, 0, 0, "tin_can_tripline", "alice")
    DeadwireNetwork.setCamouflaged(7, 0, 0, true, 100)
    viewer("bob", 5)

    tick()

    assert_eq(obj._alpha, 0.4)
end)

test("level 7 within 15 tiles is clear, and outlined orange", function()
    resetAll()
    local obj = wireAt(12, 0, 0, "tin_can_tripline", "alice")
    DeadwireNetwork.setCamouflaged(12, 0, 0, true, 100)
    viewer("bob", 7)

    tick()

    assert_eq(obj._alpha, 0.8)
    assert_true(obj._outline, "spotting somebody else's hidden wire is the "
        .. "payoff for the skill")
    assert_eq(obj._outlineCol[1], 1.00)
    assert_eq(obj._outlineCol[2], 0.50)
    assert_eq(obj._outlineCol[3], 0.00)
end)

test("an admin sees through camouflage", function()
    resetAll()
    local obj = wireAt(12, 0, 0, "tin_can_tripline", "alice")
    DeadwireNetwork.setCamouflaged(12, 0, 0, true, 100)
    viewer("staff", 0)
    _setAdmin(true)

    tick()

    assert_eq(obj._alpha, 1.0)
end)

test("AdminBypassCamo=false puts the admin back on the skill ladder", function()
    resetAll()
    SandboxVars.Deadwire.AdminBypassCamo = false
    local obj = wireAt(12, 0, 0, "tin_can_tripline", "alice")
    DeadwireNetwork.setCamouflaged(12, 0, 0, true, 100)
    viewer("staff", 0)
    _setAdmin(true)

    tick()

    assert_eq(obj._alpha, 0.0)
end)

test("an uncamouflaged wire has its alpha left alone entirely", function()
    resetAll()
    local obj = wireAt(3, 0, 0, "tin_can_tripline", "alice")
    viewer("bob", 0)
    obj._alpha = 0.5   -- whatever the engine last drew it at

    tick()

    assert_eq(obj._alpha, 0.5,
        "a plain wire is the engine's to draw; touching alpha here would fade "
        .. "wires nobody ever camouflaged")
end)

-----------------------------------------------------------------
suite("CamoVisibility: the owner outline (#29)")
-----------------------------------------------------------------

test("the owner gets an outline on an uncamouflaged wire", function()
    resetAll()
    local obj = wireAt(3, 0, 0, "tin_can_tripline", "alice")
    viewer("alice", 0)

    tick()

    assert_true(obj._outline)
end)

test("the outline colour is keyed to the wire type", function()
    resetAll()
    local bell  = wireAt(3, 0, 0, "bell_tripline", "alice")
    local tangle = wireAt(4, 0, 0, "tanglefoot", "alice")
    viewer("alice", 0)

    tick()

    assert_eq(bell._outlineCol[1], 1.00)
    assert_eq(bell._outlineCol[3], 0.25)
    assert_eq(tangle._outlineCol[1], 0.40)
    assert_eq(tangle._outlineCol[2], 0.90)
    assert_ne(bell._outlineCol[2], tangle._outlineCol[2],
        "a perimeter of mixed wire types has to be readable without walking "
        .. "up to every tile")
end)

test("a faction mate sees the outline too", function()
    resetAll()
    local obj = wireAt(3, 0, 0, "tin_can_tripline", "alice")
    _setFaction("alice", "raiders")
    _setFaction("bob", "raiders")
    viewer("bob", 0)

    tick()

    assert_true(obj._outline)
end)

test("a stranger gets no outline on somebody else's plain wire", function()
    resetAll()
    local obj = wireAt(3, 0, 0, "tin_can_tripline", "alice")
    viewer("bob", 0)

    tick()

    assert_false(obj._outline,
        "outlining every wire for everyone would give away every perimeter "
        .. "on the server")
end)

test("OwnerWireOutline=false turns it off", function()
    resetAll()
    SandboxVars.Deadwire.OwnerWireOutline = false
    local obj = wireAt(3, 0, 0, "tin_can_tripline", "alice")
    viewer("alice", 0)

    tick()

    assert_false(obj._outline)
end)

test("the outline is dropped once the wire stops being mine", function()
    resetAll()
    local obj = wireAt(3, 0, 0, "tin_can_tripline", "alice")
    viewer("alice", 0)
    tick()
    assert_true(obj._outline)

    DeadwireNetwork.getTile(3, 0, 0).ownerId = "bob"
    tick()

    assert_false(obj._outline)
end)

test("an outline this module did not set is never cleared", function()
    resetAll()
    local obj = wireAt(3, 0, 0, "tin_can_tripline", "alice")
    viewer("bob", 0)
    -- Something else in the game highlighted this object.
    obj:setOutlineHighlight(true)

    tick()

    assert_true(obj._outline,
        "reaching in and clearing the flag on every wire in range each second "
        .. "would fight anything else that ever highlights an object")
end)

-----------------------------------------------------------------
suite("CamoVisibility: what the pass skips")
-----------------------------------------------------------------

test("a wire on another floor is skipped", function()
    resetAll()
    local obj = wireAt(3, 0, 1, "tin_can_tripline", "alice")
    DeadwireNetwork.setCamouflaged(3, 0, 1, true, 100)
    viewer("bob", 0)
    obj._alpha = 0.777

    tick()

    assert_eq(obj._alpha, 0.777, "the viewer is on z=0 and that wire is upstairs")
end)

test("a wire beyond the 20 tile box is skipped", function()
    resetAll()
    local obj = wireAt(40, 0, 0, "tin_can_tripline", "alice")
    DeadwireNetwork.setCamouflaged(40, 0, 0, true, 100)
    viewer("bob", 0)
    obj._alpha = 0.777

    tick()

    assert_eq(obj._alpha, 0.777)
end)

test("both features off means the pass returns immediately", function()
    resetAll()
    SandboxVars.Deadwire.EnableCamouflage = false
    SandboxVars.Deadwire.OwnerWireOutline = false
    local obj = wireAt(3, 0, 0, "tin_can_tripline", "alice")
    DeadwireNetwork.setCamouflaged(3, 0, 0, true, 100)
    viewer("alice", 0)
    obj._alpha = 0.777

    tick()

    assert_eq(obj._alpha, 0.777)
end)

test("no local player yet: no error", function()
    resetAll()
    wireAt(3, 0, 0, "tin_can_tripline", "alice")
    DeadwireNetwork.setCamouflaged(3, 0, 0, true, 100)
    -- getPlayer() is nil before a player exists, which is the state this runs
    -- in for the first frames of a load.

    tick()
end)

test("a wire whose IsoThumpable has not arrived is picked up later (#41)", function()
    resetAll()
    local sq = _makeSquare(3, 0, 0)
    DeadwireNetwork.registerTile(3, 0, 0, 1, "tin_can_tripline", "alice")
    DeadwireNetwork.setCamouflaged(3, 0, 0, true, 100)
    viewer("bob", 0)

    tick()   -- nothing to fade yet, and no error

    -- The object sync lands. relinkIsoObject finds it by its modData marker.
    local obj = IsoThumpable.new(getCell(), sq, "deadwire_01_8", false, {})
    obj:getModData()["dw_type"] = "tin_can_tripline"
    obj._alpha = 1.0

    tick()

    assert_eq(obj._alpha, 0.0,
        "skipping the tile forever left a wire at full alpha with the player "
        .. "believing it was hidden")
end)

-----------------------------------------------------------------
suite("CamoVisibility: the perk name")
-----------------------------------------------------------------

test("Perks.Foraging does not exist and says so (#17)", function()
    local ok, err = pcall(function() return Perks.Foraging end)

    assert_false(ok, "reading it silently yielded nil, getPerkLevel(nil) "
        .. "returned 0, and every player was level 0 forever")
    assert_true(tostring(err):find("not a perk name") ~= nil)
end)

test("PlantScavenging is the real name behind the Foraging label", function()
    assert_eq(Perks.PlantScavenging, "PlantScavenging")
end)
