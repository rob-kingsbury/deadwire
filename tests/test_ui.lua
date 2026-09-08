-- tests/test_ui.lua
-- Tests for the context menu (client/UI.lua).
--
-- This file had no automated coverage at all before #47, and it is the only way
-- a player reaches any of the mod: placement, removal and camouflage all hang
-- off this one callback. A throw at the top of it takes the whole menu with it
-- and looks, in game, exactly like "the mod did not load".
--
-- What is asserted here is which options appear for whom, and what clicking one
-- actually does. Both matter: an option that appears and calls nothing is the
-- same bug as an option that never appears, and only the second one is visible
-- from a screenshot.

local function fire(playerNum, context, worldObjects, testMode)
    Events.OnFillWorldObjectContextMenu:Fire(
        playerNum, context, worldObjects, testMode)
end

-- The menu the game would hand us, already pointed at a tile.
local function menuOn(x, y, z, player, playerNum)
    local sq = getCell():getGridSquare(x, y, z)
    local context = _makeContextMenu()
    _setSpecificPlayer(playerNum or 0, player)
    fire(playerNum or 0, context, { _mockWorldObject(sq) }, false)
    return context
end

local function resetAll()
    _reset()
    _clearCommands()
end

-- A tile with a wire on it, owned by `owner`.
local function wireAt(x, y, z, wireType, owner)
    _makeSquare(x, y, z)
    DeadwireNetwork.registerTile(x, y, z, 1, wireType, owner)
    return DeadwireNetwork.getTile(x, y, z)
end

local function kitted(x, y, z, name, ...)
    local player = _mockPlayer(x, y, z, name)
    for _, wireType in ipairs({ ... }) do
        _giveItem(player, DeadwireConfig.KitItems[wireType])
    end
    return player
end

-----------------------------------------------------------------
suite("UI: options on a tile that already holds a wire")
-----------------------------------------------------------------

test("the owner is offered Remove and Camouflage", function()
    resetAll()
    wireAt(5, 5, 0, "tin_can_tripline", "alice")
    local alice = _mockPlayer(5, 6, 0, "alice")

    local context = menuOn(5, 5, 0, alice)

    assert_not_nil(_findOption(context, "Remove Tin Can Trip Line"),
        "the owner must be able to take their own wire back up")
    assert_not_nil(_findOption(context, "Camouflage Tin Can Trip Line"),
        "camouflage had no player-facing entry point at all until #42")
end)

test("the label is the friendly name, not the wireType key", function()
    resetAll()
    wireAt(5, 5, 0, "reinforced_tripline", "alice")
    local alice = _mockPlayer(5, 6, 0, "alice")

    local context = menuOn(5, 5, 0, alice)

    assert_not_nil(_findOption(context, "Remove Reinforced Trip Line"))
    assert_nil(_findOption(context, "Remove reinforced_tripline"),
        "raw keys in the menu is the bug this table was added to fix")
end)

test("a stranger is offered nothing", function()
    resetAll()
    wireAt(5, 5, 0, "tin_can_tripline", "alice")
    local bob = _mockPlayer(5, 6, 0, "bob")

    local context = menuOn(5, 5, 0, bob)

    assert_eq(#context.options, 0,
        "bob can neither remove nor camouflage a wire alice placed")
end)

test("an admin who does not own the wire is still offered Remove", function()
    resetAll()
    wireAt(5, 5, 0, "bell_tripline", "alice")
    local staff = _mockPlayer(5, 6, 0, "staff")
    _setAdmin(true)

    local context = menuOn(5, 5, 0, staff)

    assert_not_nil(_findOption(context, "Remove Bell Trip Line"),
        "an admin has to be able to clear somebody else's wire")
end)

test("an already camouflaged wire offers Remove but not Camouflage", function()
    resetAll()
    wireAt(5, 5, 0, "tanglefoot", "alice")
    DeadwireNetwork.setCamouflaged(5, 5, 0, true, 100)
    local alice = _mockPlayer(5, 6, 0, "alice")

    local context = menuOn(5, 5, 0, alice)

    assert_not_nil(_findOption(context, "Remove Tanglefoot"))
    assert_nil(_findOption(context, "Camouflage Tanglefoot"),
        "camouflaging an already camouflaged wire would just burn the timer")
end)

test("EnableCamouflage=false hides the camouflage option", function()
    resetAll()
    SandboxVars.Deadwire.EnableCamouflage = false
    wireAt(5, 5, 0, "tin_can_tripline", "alice")
    local alice = _mockPlayer(5, 6, 0, "alice")

    local context = menuOn(5, 5, 0, alice)

    assert_not_nil(_findOption(context, "Remove Tin Can Trip Line"))
    assert_nil(_findOption(context, "Camouflage Tin Can Trip Line"))
end)

-----------------------------------------------------------------
suite("UI: the placement submenu")
-----------------------------------------------------------------

test("a player holding two kits is offered exactly those two", function()
    resetAll()
    _makeSquare(5, 5, 0)
    local alice = kitted(5, 6, 0, "alice", "tin_can_tripline", "bell_tripline")

    local context = menuOn(5, 5, 0, alice)

    local parent = _findOption(context, "Place Deadwire...")
    assert_not_nil(parent, "the submenu is how every wire gets placed")

    local placeMenu = _subMenuOf(context, parent)
    assert_not_nil(placeMenu)
    assert_eq(#placeMenu.options, 2, "two kits held, two options")
    assert_not_nil(_findOption(placeMenu, "Tin Can Trip Line (1)"))
    assert_not_nil(_findOption(placeMenu, "Bell Trip Line (1)"))
    assert_nil(_findOption(placeMenu, "Tanglefoot (1)"),
        "offering a wire the player has no kit for would fail at create()")
end)

test("the count in the label is how many kits are actually held", function()
    resetAll()
    _makeSquare(5, 5, 0)
    local alice = kitted(5, 6, 0, "alice", "tin_can_tripline")
    _giveItem(alice, DeadwireConfig.KitItems.tin_can_tripline)
    _giveItem(alice, DeadwireConfig.KitItems.tin_can_tripline)

    local context = menuOn(5, 5, 0, alice)
    local placeMenu = _subMenuOf(context, _findOption(context, "Place Deadwire..."))

    assert_not_nil(_findOption(placeMenu, "Tin Can Trip Line (3)"))
end)

test("a player with no kits gets no submenu at all", function()
    resetAll()
    _makeSquare(5, 5, 0)
    local alice = _mockPlayer(5, 6, 0, "alice")

    local context = menuOn(5, 5, 0, alice)

    assert_nil(_findOption(context, "Place Deadwire..."),
        "an empty submenu is worse than none: it reads as a broken mod")
    assert_eq(#context.options, 0)
end)

test("a disabled tier is left out even while the kit is in the bag", function()
    resetAll()
    SandboxVars.Deadwire.EnableTier1 = false
    _makeSquare(5, 5, 0)
    local alice = kitted(5, 6, 0, "alice", "tin_can_tripline", "bell_tripline")

    local context = menuOn(5, 5, 0, alice)
    local placeMenu = _subMenuOf(context, _findOption(context, "Place Deadwire..."))

    assert_eq(#placeMenu.options, 1, "bell is tier 1 and tier 1 is off")
    assert_not_nil(_findOption(placeMenu, "Tin Can Trip Line (1)"))
end)

test("clicking a placement option hands the engine the right build object", function()
    resetAll()
    _makeSquare(5, 5, 0)
    local alice = kitted(5, 6, 0, "alice", "bell_tripline")

    local context = menuOn(5, 5, 0, alice)
    local placeMenu = _subMenuOf(context, _findOption(context, "Place Deadwire..."))
    _clickOption(_findOption(placeMenu, "Bell Trip Line (1)"))

    local drag = _lastDragged()
    assert_not_nil(drag, "the menu has to reach setDrag or nothing is placeable")
    assert_eq(drag.obj.wireType, "bell_tripline")
    assert_eq(drag.playerNum, 0)
end)

-----------------------------------------------------------------
suite("UI: the menu refuses to build at all")
-----------------------------------------------------------------

test("test mode adds nothing", function()
    resetAll()
    wireAt(5, 5, 0, "tin_can_tripline", "alice")
    local alice = _mockPlayer(5, 6, 0, "alice")
    local sq = getCell():getGridSquare(5, 5, 0)
    local context = _makeContextMenu()
    _setSpecificPlayer(0, alice)

    fire(0, context, { _mockWorldObject(sq) }, true)

    assert_eq(#context.options, 0,
        "the engine calls this once to size the menu; building it twice "
        .. "duplicates every option")
end)

test("EnableMod=false adds nothing", function()
    resetAll()
    SandboxVars.Deadwire.EnableMod = false
    wireAt(5, 5, 0, "tin_can_tripline", "alice")
    local alice = _mockPlayer(5, 6, 0, "alice")

    local context = menuOn(5, 5, 0, alice)

    assert_eq(#context.options, 0)
end)

test("no player behind that index: no options, no error", function()
    resetAll()
    wireAt(5, 5, 0, "tin_can_tripline", "alice")
    local sq = getCell():getGridSquare(5, 5, 0)
    local context = _makeContextMenu()

    fire(0, context, { _mockWorldObject(sq) }, false)

    assert_eq(#context.options, 0)
end)

test("world objects with no square: no options, no error", function()
    resetAll()
    local alice = kitted(5, 6, 0, "alice", "tin_can_tripline")
    _setSpecificPlayer(0, alice)
    local context = _makeContextMenu()

    fire(0, context, { _mockWorldObject(nil) }, false)

    assert_eq(#context.options, 0,
        "right-clicking empty air must not throw out of the menu callback")
end)

-----------------------------------------------------------------
suite("UI: acting on a wire walks the player to it first")
--
-- The server bounds how far a player may be from a wire they act on (#36) and
-- a context menu opens on any tile on screen. Firing the command straight from
-- the menu would be refused for every click more than four tiles out, which is
-- most of them -- and would be #31 all over again.
-----------------------------------------------------------------

test("Remove queues a timed action for that exact tile", function()
    resetAll()
    wireAt(5, 5, 0, "tin_can_tripline", "alice")
    local alice = _mockPlayer(9, 9, 0, "alice")

    local context = menuOn(5, 5, 0, alice)
    _clickOption(_findOption(context, "Remove Tin Can Trip Line"))

    assert_eq(#_walkAdjCalls, 1, "the walk is what puts the player in range")
    assert_eq(_walkAdjCalls[1].square:getX(), 5)

    local action = _lastQueuedAction()
    assert_not_nil(action, "no action queued means the click did nothing")
    assert_eq(action.command, "RemoveWire")
    assert_eq(action.wx, 5)
    assert_eq(action.wy, 5)
    assert_eq(action.wz, 0)
end)

test("Camouflage queues its own command and a longer timer", function()
    resetAll()
    wireAt(5, 5, 0, "tin_can_tripline", "alice")
    local alice = _mockPlayer(9, 9, 0, "alice")

    local context = menuOn(5, 5, 0, alice)
    _clickOption(_findOption(context, "Camouflage Tin Can Trip Line"))

    local action = _lastQueuedAction()
    assert_eq(action.command, "CamouflageWire")
    assert_gte(action.maxTime, 250, "camouflaging is meant to be slower than removal")
end)

test("nowhere to stand: nothing is queued", function()
    resetAll()
    wireAt(5, 5, 0, "tin_can_tripline", "alice")
    local alice = _mockPlayer(9, 9, 0, "alice")
    _setWalkAdj(false)

    local context = menuOn(5, 5, 0, alice)
    _clickOption(_findOption(context, "Remove Tin Can Trip Line"))

    assert_nil(_lastQueuedAction(),
        "vanilla queues nothing when walkAdj refuses, and so do we")
end)

test("the command is not sent from the menu itself", function()
    resetAll()
    wireAt(5, 5, 0, "tin_can_tripline", "alice")
    local alice = _mockPlayer(9, 9, 0, "alice")

    local context = menuOn(5, 5, 0, alice)
    _clickOption(_findOption(context, "Remove Tin Can Trip Line"))

    assert_eq(#_sentClient, 0,
        "sending here rather than from the action's perform() is what the "
        .. "server's distance bound would refuse (#36)")
end)
