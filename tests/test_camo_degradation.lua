-- tests/test_camo_degradation.lua
-- Tests for rain wearing camouflage off (server/CamoDegradation.lua).
--
-- The whole file was dead for a release: it called
-- Climate.GetInstance():getRainStrength(), and no part of that exists in 42.20,
-- so the rain intensity was always 0 and camouflage never degraded from weather
-- at all (#18). Two guards swallowed it and the log stayed clean. That is the
-- reason the arithmetic below is asserted at specific intensities rather than
-- "degradation happens".

local function resetAll()
    _reset()
    _clearCommands()
    _clearModData()
end

local function camoWireAt(x, y, z, durability)
    _makeSquare(x, y, z)
    DeadwireNetwork.registerTile(x, y, z, 1, "tin_can_tripline", "alice")
    DeadwireNetwork.setCamouflaged(x, y, z, true, durability)
    return DeadwireNetwork.getTile(x, y, z)
end

local function rains(intensity)
    _setRainIntensity(intensity)
    Events.EveryTenMinutes:Fire()
end

-----------------------------------------------------------------
suite("CamoDegradation: the rain arithmetic")
--
-- Default base rate is 5 per ten in-game minutes, storm multiplier 2.0, and
-- the storm branch starts at intensity 0.8.
-----------------------------------------------------------------

test("light rain rounds down to nothing", function()
    resetAll()
    local wire = camoWireAt(1, 1, 0, 100)

    rains(0.1)   -- floor(5 * 0.1) = 0

    assert_eq(wire.camoDurability, 100,
        "a drizzle costing zero is the honest result of integer degradation, "
        .. "not a bug to round up")
end)

test("moderate rain takes two points", function()
    resetAll()
    local wire = camoWireAt(1, 1, 0, 100)

    rains(0.5)   -- floor(5 * 0.5) = 2

    assert_eq(wire.camoDurability, 98)
end)

test("a storm takes ten", function()
    resetAll()
    local wire = camoWireAt(1, 1, 0, 100)

    rains(0.9)   -- floor(5 * 2.0) = 10

    assert_eq(wire.camoDurability, 90)
end)

test("the storm branch starts exactly at 0.8", function()
    resetAll()
    local wire = camoWireAt(1, 1, 0, 100)

    rains(0.8)

    assert_eq(wire.camoDurability, 90,
        "0.8 is the threshold itself, and >= is what the code says")
end)

test("just under the threshold is still the linear branch", function()
    resetAll()
    local wire = camoWireAt(1, 1, 0, 100)

    rains(0.79)  -- floor(5 * 0.79) = 3

    assert_eq(wire.camoDurability, 97)
end)

test("CamoRainDegradeRate is what scales it", function()
    resetAll()
    SandboxVars.Deadwire.CamoRainDegradeRate = 20
    local wire = camoWireAt(1, 1, 0, 100)

    rains(0.5)   -- floor(20 * 0.5) = 10

    assert_eq(wire.camoDurability, 90)
end)

test("CamoStormMultiplier is what scales the storm", function()
    resetAll()
    SandboxVars.Deadwire.CamoStormMultiplier = 4.0
    local wire = camoWireAt(1, 1, 0, 100)

    rains(0.9)   -- floor(5 * 4.0) = 20

    assert_eq(wire.camoDurability, 80)
end)

test("dry weather does nothing at all", function()
    resetAll()
    local wire = camoWireAt(1, 1, 0, 100)

    rains(0)

    assert_eq(wire.camoDurability, 100)
    assert_eq(#_sentServer, 0)
end)

-----------------------------------------------------------------
suite("CamoDegradation: camouflage running out")
-----------------------------------------------------------------

test("durability reaching zero strips the camouflage", function()
    resetAll()
    local wire = camoWireAt(1, 1, 0, 8)

    rains(0.9)   -- 8 - 10 goes below zero

    assert_false(wire.camouflaged)
    assert_eq(wire.camoDurability, 0)
end)

test("the wire drops out of the camo index when it expires", function()
    resetAll()
    camoWireAt(1, 1, 0, 8)

    rains(0.9)

    local remaining = 0
    for _ in pairs(DeadwireNetwork.getCamoTiles()) do remaining = remaining + 1 end
    assert_eq(remaining, 0,
        "leaving it indexed means the next rain tick degrades a wire that is "
        .. "no longer camouflaged")
end)

test("expiry is broadcast so clients stop hiding it", function()
    resetAll()
    camoWireAt(1, 1, 0, 8)

    rains(0.9)

    local sent = _findServerCmd("WireCamouflaged")
    assert_not_nil(sent, "without the broadcast a multiplayer client keeps the "
        .. "wire at alpha 0: invisible and armed")
    assert_eq(sent.args.x, 1)
    assert_false(sent.args.camouflaged)
    assert_eq(sent.args.durability, 0)
end)

test("landing exactly on zero counts as expired", function()
    resetAll()
    local wire = camoWireAt(1, 1, 0, 10)

    rains(0.9)   -- 10 - 10 = 0

    assert_false(wire.camouflaged,
        "zero durability with the camo flag still set is a wire that is "
        .. "hidden and worn out at the same time")
end)

test("a surviving wire is not broadcast", function()
    resetAll()
    camoWireAt(1, 1, 0, 100)

    rains(0.9)

    assert_eq(#_sentServer, 0,
        "one packet per camouflaged wire per ten minutes, for a number no "
        .. "client reads until it hits zero")
end)

test("several wires degrade together and only the spent one expires", function()
    resetAll()
    local doomed   = camoWireAt(1, 1, 0, 5)
    local survivor = camoWireAt(2, 2, 0, 100)

    rains(0.9)

    assert_false(doomed.camouflaged)
    assert_true(survivor.camouflaged)
    assert_eq(survivor.camoDurability, 90)
end)

-----------------------------------------------------------------
suite("CamoDegradation: where it must not run")
-----------------------------------------------------------------

test("a multiplayer client degrades nothing (#35)", function()
    resetAll()
    local wire = camoWireAt(1, 1, 0, 100)
    _setClient(true)

    rains(0.9)

    assert_eq(wire.camoDurability, 100,
        "the client's copy never sees the server's trigger-degrade updates, "
        .. "so the two would expire camo at different times and leave the "
        .. "wire invisible and armed until the broadcast caught up")
end)

test("EnableCamouflage=false stops the pass", function()
    resetAll()
    SandboxVars.Deadwire.EnableCamouflage = false
    local wire = camoWireAt(1, 1, 0, 100)

    rains(0.9)

    assert_eq(wire.camoDurability, 100)
end)

test("an uncamouflaged wire is never touched", function()
    resetAll()
    _makeSquare(1, 1, 0)
    DeadwireNetwork.registerTile(1, 1, 0, 1, "tin_can_tripline", "alice")

    rains(0.9)

    assert_eq(#_sentServer, 0)
    assert_false(DeadwireNetwork.getTile(1, 1, 0).camouflaged)
    assert_eq(DeadwireNetwork.getTile(1, 1, 0).camoDurability, 0)
end)
