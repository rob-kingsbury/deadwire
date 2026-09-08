-- tests/test_salvage.lua
-- Tests for what a wire leaves behind when it stops existing.
--
-- Two different events with two different answers, which is the whole design.
-- A wire something walked into came apart, so it scatters a rolled fraction of
-- its durable parts. A wire a player pulled up by hand comes back as the kit,
-- whole, because making a careful pickup a gamble punishes doing it properly.
--
-- Before this, both left absolutely nothing on the tile. Rob, watching a tin
-- can line break in a real game: "it just looks like a bug."

local function resetAll()
    _reset()
    _clearCommands()
    _clearModData()
    _clearSounds()
end

local function wireAt(x, y, z, wireType, owner)
    local sq = _makeSquare(x, y, z)
    DeadwireNetwork.registerTile(x, y, z, 1, wireType, owner or "alice")
    DeadwireWireManager.saveWire(x, y, z, 1, wireType, owner or "alice")
    return sq
end

-- A player standing on a real square. withinReach and the trigger sanity
-- bound both read player:getSquare(), so a mock with no square underneath it
-- is refused for reasons that have nothing to do with what is being tested.
local function playerAt(x, y, z, name)
    _makeSquare(x, y, z)
    return _mockPlayer(x, y, z, name)
end

local function itemsOn(sq)
    return sq._worldItems
end

local function countOn(sq, fullType)
    local n = 0
    for _, it in ipairs(sq._worldItems) do
        if it == fullType then n = n + 1 end
    end
    return n
end

-----------------------------------------------------------------
suite("Salvage: the roll")
--
-- ZombRand is fixed in the stubs, so these are exact rather than statistical.
-- rollSalvagePercent is min + ZombRand(max - min + 1), default range 0 to 60.
-----------------------------------------------------------------

test("a full roll returns every durable part", function()
    resetAll()
    SandboxVars.Deadwire.SalvageMinPercent = 100
    SandboxVars.Deadwire.SalvageMaxPercent = 100
    local sq = wireAt(1, 1, 0, "tin_can_tripline")

    DeadwireWireManager.salvageWire("tin_can_tripline", sq)

    assert_eq(countOn(sq, "Base.TinCanEmpty"), 3, "the recipe takes three cans")
    assert_eq(countOn(sq, "Base.Nails"), 2)
end)

test("a zero roll leaves nothing", function()
    resetAll()
    SandboxVars.Deadwire.SalvageMinPercent = 0
    SandboxVars.Deadwire.SalvageMaxPercent = 0
    local sq = wireAt(1, 1, 0, "tin_can_tripline")

    DeadwireWireManager.salvageWire("tin_can_tripline", sq)

    assert_eq(#itemsOn(sq), 0, "zero percent means the line was wrecked")
end)

test("half a wire is half of everything, floored", function()
    resetAll()
    SandboxVars.Deadwire.SalvageMinPercent = 50
    SandboxVars.Deadwire.SalvageMaxPercent = 50
    local sq = wireAt(1, 1, 0, "tin_can_tripline")

    DeadwireWireManager.salvageWire("tin_can_tripline", sq)

    assert_eq(countOn(sq, "Base.TinCanEmpty"), 1, "floor(3 * 0.5)")
    assert_eq(countOn(sq, "Base.Nails"), 1, "floor(2 * 0.5)")
end)

test("one roll for the whole wire, not one per slot", function()
    resetAll()
    SandboxVars.Deadwire.SalvageMinPercent = 0
    SandboxVars.Deadwire.SalvageMaxPercent = 100
    -- The first roll is everything, the second is nothing. A wire that rolls
    -- once uses only the first and returns all five parts; a wire that rolls
    -- per slot gets 100% on the cans and 0% on the nails and returns three.
    _setZombRand(100, 0)
    local sq = wireAt(1, 1, 0, "tin_can_tripline")

    DeadwireWireManager.salvageWire("tin_can_tripline", sq)

    assert_eq(#itemsOn(sq), 5,
        "independent rolls per slot would average out and never look like a "
        .. "bad break to the player picking through the grass")
    assert_eq(countOn(sq, "Base.Nails"), 2,
        "the nails are the slot a second roll would have zeroed")
end)

test("a max below the min does not invert the range", function()
    resetAll()
    SandboxVars.Deadwire.SalvageMinPercent = 80
    SandboxVars.Deadwire.SalvageMaxPercent = 10

    -- Unclamped this computes ZombRand(10 - 80 + 1), a negative bound. The
    -- stub refuses that rather than quietly returning 0, so the assertion is
    -- that the call survives at all as much as what it returns.
    local ok, pct = pcall(DeadwireConfig.rollSalvagePercent)

    assert_true(ok, "a server owner setting these backwards must not throw: "
        .. tostring(pct))
    assert_eq(pct, 80)
end)

-----------------------------------------------------------------
suite("Salvage: what comes back and what does not")
-----------------------------------------------------------------

test("cord never comes back, because cord is what snapped", function()
    resetAll()
    SandboxVars.Deadwire.SalvageMinPercent = 100
    SandboxVars.Deadwire.SalvageMaxPercent = 100
    local sq = wireAt(1, 1, 0, "tin_can_tripline")

    DeadwireWireManager.salvageWire("tin_can_tripline", sq)

    for _, cord in ipairs({ "Base.Twine", "Base.FishingLine", "Base.ElectricWire" }) do
        assert_eq(countOn(sq, cord), 0, cord .. " should never be salvaged")
    end
end)

test("each wire type returns its own parts", function()
    resetAll()
    SandboxVars.Deadwire.SalvageMinPercent = 100
    SandboxVars.Deadwire.SalvageMaxPercent = 100

    local bell = wireAt(1, 1, 0, "bell_tripline")
    DeadwireWireManager.salvageWire("bell_tripline", bell)
    assert_eq(countOn(bell, "Base.Bell"), 1, "the bell is the expensive part")
    assert_eq(countOn(bell, "Base.Wire"), 1)
    assert_eq(countOn(bell, "Base.TinCanEmpty"), 0, "a bell line has no cans")

    local tangle = wireAt(2, 2, 0, "tanglefoot")
    DeadwireWireManager.salvageWire("tanglefoot", tangle)
    assert_eq(countOn(tangle, "Base.TreeBranch2"), 3)
    assert_eq(countOn(tangle, "Base.Nails"), 2)
end)

test("an unknown wire type drops nothing and says so", function()
    resetAll()
    SandboxVars.Deadwire.SalvageMinPercent = 100
    SandboxVars.Deadwire.SalvageMaxPercent = 100
    local sq = _makeSquare(1, 1, 0)

    local dropped = DeadwireWireManager.salvageWire("definitely_not_a_wire", sq)

    assert_eq(dropped, 0)
    assert_eq(#itemsOn(sq), 0)
end)

test("no square: no drop, no error", function()
    resetAll()

    assert_eq(DeadwireWireManager.salvageWire("tin_can_tripline", nil), 0)
end)

-----------------------------------------------------------------
suite("Salvage: a wire that gets triggered and breaks")
-----------------------------------------------------------------

test("a broken tin can line leaves its parts on the tile", function()
    resetAll()
    SandboxVars.Deadwire.SalvageMinPercent = 100
    SandboxVars.Deadwire.SalvageMaxPercent = 100
    local sq = wireAt(5, 5, 0, "tin_can_tripline")
    local reporter = playerAt(5, 6, 0, "alice")
    _mockZombie(5, 5, 0)

    Events.OnClientCommand:Fire(DeadwireConfig.MODULE, "WireTriggered", reporter,
        { x = 5, y = 5, z = 0, wireType = "tin_can_tripline" })

    assert_nil(DeadwireNetwork.getTile(5, 5, 0), "single-use wire should be gone")
    assert_eq(countOn(sq, "Base.TinCanEmpty"), 3,
        "an empty tile is what made this read as a bug rather than a mechanic")
end)

test("a reusable wire is not destroyed and drops nothing", function()
    resetAll()
    SandboxVars.Deadwire.SalvageMinPercent = 100
    SandboxVars.Deadwire.SalvageMaxPercent = 100
    local sq = wireAt(5, 5, 0, "bell_tripline")
    local reporter = playerAt(5, 6, 0, "alice")
    _mockZombie(5, 5, 0)

    Events.OnClientCommand:Fire(DeadwireConfig.MODULE, "WireTriggered", reporter,
        { x = 5, y = 5, z = 0, wireType = "bell_tripline" })

    assert_not_nil(DeadwireNetwork.getTile(5, 5, 0), "a bell line is reusable")
    assert_eq(#itemsOn(sq), 0, "salvaging a wire that still exists would be "
        .. "free materials on every trigger")
end)

-----------------------------------------------------------------
suite("Salvage: a wire a player picks back up")
-----------------------------------------------------------------

test("removing your own wire returns the whole kit", function()
    resetAll()
    wireAt(5, 5, 0, "bell_tripline", "alice")
    local alice = playerAt(5, 6, 0, "alice")

    Events.OnClientCommand:Fire(DeadwireConfig.MODULE, "RemoveWire", alice,
        { x = 5, y = 5, z = 0 })

    assert_nil(DeadwireNetwork.getTile(5, 5, 0))
    assert_eq(_countItems(alice, DeadwireConfig.KitItems.bell_tripline), 1,
        "a careful pickup returning nothing punished doing it properly")
end)

test("the kit goes to the player, not onto the ground", function()
    resetAll()
    local sq = wireAt(5, 5, 0, "tin_can_tripline", "alice")
    local alice = playerAt(5, 6, 0, "alice")

    Events.OnClientCommand:Fire(DeadwireConfig.MODULE, "RemoveWire", alice,
        { x = 5, y = 5, z = 0 })

    assert_eq(#itemsOn(sq), 0, "you picked it up, it is in your hands")
    assert_eq(_countItems(alice, DeadwireConfig.KitItems.tin_can_tripline), 1)
end)

test("the pickup is not a gamble, whatever the salvage range says", function()
    resetAll()
    SandboxVars.Deadwire.SalvageMinPercent = 0
    SandboxVars.Deadwire.SalvageMaxPercent = 0
    wireAt(5, 5, 0, "tanglefoot", "alice")
    local alice = playerAt(5, 6, 0, "alice")

    Events.OnClientCommand:Fire(DeadwireConfig.MODULE, "RemoveWire", alice,
        { x = 5, y = 5, z = 0 })

    assert_eq(_countItems(alice, DeadwireConfig.KitItems.tanglefoot), 1,
        "the salvage roll belongs to destruction alone")
end)

test("a refused removal returns nothing", function()
    resetAll()
    wireAt(5, 5, 0, "bell_tripline", "alice")
    local bob = playerAt(5, 6, 0, "bob")

    Events.OnClientCommand:Fire(DeadwireConfig.MODULE, "RemoveWire", bob,
        { x = 5, y = 5, z = 0 })

    assert_not_nil(DeadwireNetwork.getTile(5, 5, 0), "bob does not own it")
    assert_eq(_countItems(bob, DeadwireConfig.KitItems.bell_tripline), 0,
        "handing a kit to someone whose removal was refused would be free "
        .. "kits for anyone who clicks a stranger's wire")
end)

test("a removal refused for distance returns nothing", function()
    resetAll()
    wireAt(5, 5, 0, "bell_tripline", "alice")
    local alice = playerAt(40, 40, 0, "alice")

    Events.OnClientCommand:Fire(DeadwireConfig.MODULE, "RemoveWire", alice,
        { x = 5, y = 5, z = 0 })

    assert_not_nil(DeadwireNetwork.getTile(5, 5, 0))
    assert_eq(_countItems(alice, DeadwireConfig.KitItems.bell_tripline), 0)
end)
