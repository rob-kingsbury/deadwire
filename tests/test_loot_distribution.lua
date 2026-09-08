-- tests/test_loot_distribution.lua
-- Tests for loot injection (server/LootDistribution.lua).
--
-- Two bugs have lived in this file, and neither showed up as an error. It
-- guarded on `not isServer()`, which is true in single player, so no Deadwire
-- loot ever spawned in any single-player game for the mod's whole life. And it
-- named ChurchStorageMisc, a distribution 42.20 does not have, added as a
-- "verified" replacement for the equally nonexistent ChurchMisc.
--
-- Both are the same shape: an absence that logs nothing. So the assertions here
-- are about the count of tables that actually took the item, and about the
-- warning firing when one is missing.

local BELL_DISTS = {
    "FarmerTools", "BarnTools", "ToolStoreTools", "GardenStoreTools",
    "SchoolLockers", "OfficeDeskHome", "JanitorMisc",
}
local KIT_DISTS = {
    "MetalShopTools", "MetalWorkerTools", "WeldingWorkshopMetal", "GarageMetalwork",
}

-- Capture what the module logs, so the missing-name warning can be asserted
-- rather than trusted.
local _logged = {}
local _realLog = DeadwireConfig.log
local function captureLog()
    _logged = {}
    DeadwireConfig.log = function(msg) table.insert(_logged, tostring(msg)) end
end
local function releaseLog() DeadwireConfig.log = _realLog end

local function loggedMatching(pattern)
    for _, msg in ipairs(_logged) do
        if msg:find(pattern, 1, true) then return msg end
    end
    return nil
end

local function resetAll()
    _reset()
    for _, name in ipairs(BELL_DISTS) do _addDistribution(name) end
    for _, name in ipairs(KIT_DISTS) do _addDistribution(name) end
end

local function merge()
    captureLog()
    Events.OnPreDistributionMerge:Fire()
    releaseLog()
end

-- Distributions store a flat list alternating item, chance. Return the chance
-- recorded for an item, or nil.
local function chanceFor(distName, item)
    local dist = ProceduralDistributions.list[distName]
    if not dist then return nil end
    for i = 1, #dist.items - 1, 2 do
        if dist.items[i] == item then return dist.items[i + 1] end
    end
    return nil
end

local function countHolding(names, item)
    local n = 0
    for _, name in ipairs(names) do
        if chanceFor(name, item) then n = n + 1 end
    end
    return n
end

-----------------------------------------------------------------
suite("LootDistribution: what gets injected where")
-----------------------------------------------------------------

test("bells reach all seven of their tables", function()
    resetAll()

    merge()

    assert_eq(countHolding(BELL_DISTS, "Base.Bell"), 7)
end)

test("reinforced kits reach all four metalworking tables (#12)", function()
    resetAll()

    merge()

    assert_eq(countHolding(KIT_DISTS, "Base.Deadwire_ReinforcedTripLineKit"), 4)
end)

test("bells do not leak into the metalworking tables", function()
    resetAll()

    merge()

    assert_nil(chanceFor("MetalShopTools", "Base.Bell"))
    assert_nil(chanceFor("FarmerTools", "Base.Deadwire_ReinforcedTripLineKit"))
end)

test("the item and its chance go in as a pair", function()
    resetAll()

    merge()

    local items = ProceduralDistributions.list.FarmerTools.items
    assert_eq(#items, 2, "one item, one chance, appended in that order")
    assert_eq(items[1], "Base.Bell")
    assert_eq(items[2], 12)
end)

-----------------------------------------------------------------
suite("LootDistribution: the spawn rate enum")
-----------------------------------------------------------------

test("the default rate is Common, chance 12", function()
    resetAll()

    merge()

    assert_eq(chanceFor("FarmerTools", "Base.Bell"), 12)
end)

test("Rare is chance 2", function()
    resetAll()
    SandboxVars.Deadwire.BellSpawnRate = 1

    merge()

    assert_eq(chanceFor("FarmerTools", "Base.Bell"), 2)
end)

test("Abundant is chance 20", function()
    resetAll()
    SandboxVars.Deadwire.BellSpawnRate = 4

    merge()

    assert_eq(chanceFor("FarmerTools", "Base.Bell"), 20)
end)

test("a rate outside the enum falls back to Common", function()
    resetAll()
    SandboxVars.Deadwire.BellSpawnRate = 99

    merge()

    assert_eq(chanceFor("FarmerTools", "Base.Bell"), 12)
end)

-----------------------------------------------------------------
suite("LootDistribution: a name the game does not have")
-----------------------------------------------------------------

test("a missing distribution warns loudly instead of passing quietly", function()
    resetAll()
    ProceduralDistributions.list.FarmerTools = nil

    merge()

    local warning = loggedMatching("no distribution 'FarmerTools'")
    assert_not_nil(warning,
        "every bug this file has had was a name resolving to nil and producing "
        .. "an absent feature with a clean log")
    assert_true(warning:find("Base.Bell") ~= nil,
        "the warning has to say which item will not spawn")
end)

test("the other tables still get the item", function()
    resetAll()
    ProceduralDistributions.list.FarmerTools = nil

    merge()

    assert_eq(countHolding(BELL_DISTS, "Base.Bell"), 6,
        "one bad name must not cost the other six")
end)

test("the summary reports the count that actually took it", function()
    resetAll()
    ProceduralDistributions.list.FarmerTools = nil

    merge()

    assert_not_nil(loggedMatching("6 tables"),
        "a summary that reported seven would be the checker blessing the bug")
end)

-----------------------------------------------------------------
suite("LootDistribution: where it must not run")
-----------------------------------------------------------------

test("a multiplayer client injects nothing", function()
    resetAll()
    _setClient(true)

    merge()

    assert_eq(countHolding(BELL_DISTS, "Base.Bell"), 0)
end)

test("single player DOES inject: isServer() is false there (#18)", function()
    resetAll()
    _setClient(false)

    merge()

    assert_eq(countHolding(BELL_DISTS, "Base.Bell"), 7,
        "guarding on `not isServer()` returned immediately in single player, "
        .. "so no Deadwire loot spawned in any SP game for the mod's whole life")
end)

test("EnableMod=false injects nothing", function()
    resetAll()
    SandboxVars.Deadwire.EnableMod = false

    merge()

    assert_eq(countHolding(BELL_DISTS, "Base.Bell"), 0)
    assert_eq(countHolding(KIT_DISTS, "Base.Deadwire_ReinforcedTripLineKit"), 0)
end)
