-- tests/test_event_handlers.lua
-- Tests for the OnServerCommand listener (client/EventHandlers.lua).
--
-- Everything in this file is dead in single player: sendServerCommand is a
-- no-op except on a real dedicated server, and the mod works in SP only because
-- both halves share one tileIndex in memory. So none of this has ever run in a
-- game Rob has played, and the first time it does will be on a server with
-- other people on it.
--
-- The join sync is the part that matters most. Until #33 it hung off
-- Events.OnPlayerConnect, a name the game does not have, so a joining client
-- had an empty WireNetwork: detection ignored every wire, the context menu
-- never offered Remove on the player's own wire, and camouflage hid nothing.

local function resetAll()
    _reset()
    _clearCommands()
    _clearSounds()
end

local function server(command, args)
    Events.OnServerCommand:Fire(DeadwireConfig.MODULE, command, args)
end

local function wireAt(x, y, z, wireType, owner)
    _makeSquare(x, y, z)
    DeadwireNetwork.registerTile(x, y, z, 1, wireType, owner or "alice")
end

-----------------------------------------------------------------
suite("EventHandlers: dispatch")
-----------------------------------------------------------------

test("another mod's commands are ignored", function()
    resetAll()
    _makeSquare(1, 1, 0)

    Events.OnServerCommand:Fire("SomeOtherMod", "WirePlaced", {
        x = 1, y = 1, z = 0, networkId = 1, wireType = "tin_can_tripline",
    })

    assert_nil(DeadwireNetwork.getTile(1, 1, 0),
        "every mod on the server sees every server command")
end)

test("an unknown command is survivable", function()
    resetAll()

    server("NoSuchCommand", { x = 1, y = 1, z = 0 })
end)

test("a command with no position is dropped rather than throwing", function()
    resetAll()

    server("WirePlaced", {})
    server("WireDestroyed", nil)
    server("WireCamouflaged", { x = 1 })
end)

-----------------------------------------------------------------
suite("EventHandlers: WirePlaced and WireDestroyed")
-----------------------------------------------------------------

test("WirePlaced puts the wire in this client's network", function()
    resetAll()
    _makeSquare(4, 5, 0)

    server("WirePlaced", {
        x = 4, y = 5, z = 0, networkId = 7,
        wireType = "bell_tripline", ownerId = "alice",
    })

    local wire = DeadwireNetwork.getTile(4, 5, 0)
    assert_not_nil(wire, "without this the client cannot detect its own wires")
    assert_eq(wire.wireType, "bell_tripline")
    assert_eq(wire.ownerId, "alice")
    assert_eq(wire.networkId, 7)
end)

test("WirePlaced links the IsoThumpable when the chunk is already loaded", function()
    resetAll()
    local sq = _makeSquare(4, 5, 0)
    local obj = IsoThumpable.new(getCell(), sq, "deadwire_01_0", false, {})
    obj:getModData()["dw_type"] = "bell_tripline"

    server("WirePlaced", {
        x = 4, y = 5, z = 0, networkId = 7,
        wireType = "bell_tripline", ownerId = "alice",
    })

    assert_eq(DeadwireNetwork.getTile(4, 5, 0).isoObject, obj,
        "camouflage cannot fade an object the client never found")
end)

test("WireDestroyed takes it back out", function()
    resetAll()
    wireAt(4, 5, 0, "bell_tripline")

    server("WireDestroyed", { x = 4, y = 5, z = 0 })

    assert_nil(DeadwireNetwork.getTile(4, 5, 0))
end)

-----------------------------------------------------------------
suite("EventHandlers: WireTriggered")
-----------------------------------------------------------------

test("the server's cooldown is mirrored locally", function()
    resetAll()
    wireAt(4, 5, 0, "bell_tripline")
    _setOsTime(1000)

    server("WireTriggered", { x = 4, y = 5, z = 0, cooldownSeconds = 36 })

    assert_true(DeadwireNetwork.isOnCooldown(4, 5, 0),
        "detection checks this client's own copy, so without the mirror the "
        .. "wire re-arms immediately on every client")
    _setOsTime(1040)
    assert_false(DeadwireNetwork.isOnCooldown(4, 5, 0))
end)

test("the broadcast sound is played at the wire", function()
    resetAll()
    wireAt(4, 5, 0, "bell_tripline")

    server("WireTriggered", {
        x = 4, y = 5, z = 0,
        soundName = DeadwireConfig.Sounds.BELL_RING, audioRadius = 60,
    })

    local sound = _lastWorldSound()
    assert_not_nil(sound)
    assert_eq(sound.name, DeadwireConfig.Sounds.BELL_RING)
    assert_eq(sound.radius, 60)
    assert_eq(sound.sq:getX(), 4)
end)

test("no soundName means silence, not a default", function()
    resetAll()
    wireAt(4, 5, 0, "tanglefoot")

    server("WireTriggered", { x = 4, y = 5, z = 0, cooldownSeconds = 0 })

    assert_eq(#_getWorldSounds(), 0,
        "the old default of TIN_CAN_RATTLE would have made the silent trap "
        .. "audible, which is the one thing tanglefoot must never be")
end)

test("a sound for a tile this client has not loaded is skipped", function()
    resetAll()

    server("WireTriggered", {
        x = 900, y = 900, z = 0, soundName = DeadwireConfig.Sounds.BELL_RING,
    })

    assert_eq(#_getWorldSounds(), 0)
end)

-----------------------------------------------------------------
suite("EventHandlers: WireCamouflaged")
-----------------------------------------------------------------

test("camouflage state and durability both arrive", function()
    resetAll()
    wireAt(4, 5, 0, "tin_can_tripline")

    server("WireCamouflaged", {
        x = 4, y = 5, z = 0, camouflaged = true, durability = 80,
    })

    local wire = DeadwireNetwork.getTile(4, 5, 0)
    assert_true(wire.camouflaged)
    assert_eq(wire.camoDurability, 80)
end)

test("losing camouflage puts the wire back to full alpha", function()
    resetAll()
    local sq = _makeSquare(4, 5, 0)
    DeadwireNetwork.registerTile(4, 5, 0, 1, "tin_can_tripline", "alice")
    local obj = IsoThumpable.new(getCell(), sq, "deadwire_01_8", false, {})
    DeadwireNetwork.setIsoObject(4, 5, 0, obj)
    server("WireCamouflaged", { x = 4, y = 5, z = 0, camouflaged = true, durability = 80 })
    obj._alpha = 0.0

    server("WireCamouflaged", { x = 4, y = 5, z = 0, camouflaged = false, durability = 0 })

    assert_eq(obj._alpha, 1.0,
        "the reset lives inside setCamouflaged now, because this handler only "
        .. "ever runs on a multiplayer client and single player never got it (#35)")
end)

-----------------------------------------------------------------
suite("EventHandlers: the join sync (#33)")
-----------------------------------------------------------------

test("a joining client is handed every wire at once", function()
    resetAll()
    _makeSquare(1, 1, 0)
    _makeSquare(2, 2, 0)

    server("WireNetworkSync", { wires = {
        { x = 1, y = 1, z = 0, networkId = 1, wireType = "tin_can_tripline", ownerId = "alice" },
        { x = 2, y = 2, z = 0, networkId = 2, wireType = "bell_tripline", ownerId = "bob" },
    } })

    assert_not_nil(DeadwireNetwork.getTile(1, 1, 0))
    assert_eq(DeadwireNetwork.getTile(2, 2, 0).ownerId, "bob")
end)

test("camouflaged wires arrive camouflaged", function()
    resetAll()
    _makeSquare(1, 1, 0)

    server("WireNetworkSync", { wires = {
        { x = 1, y = 1, z = 0, networkId = 1, wireType = "tin_can_tripline",
          ownerId = "alice", camouflaged = true, camoDurability = 55 },
    } })

    local wire = DeadwireNetwork.getTile(1, 1, 0)
    assert_true(wire.camouflaged)
    assert_eq(wire.camoDurability, 55)
end)

test("a wire missing required fields is skipped, not half-registered", function()
    resetAll()
    _makeSquare(1, 1, 0)
    _makeSquare(2, 2, 0)

    server("WireNetworkSync", { wires = {
        { x = 1, y = 1, z = 0, wireType = "tin_can_tripline" },  -- no networkId
        { x = 2, y = 2, z = 0, networkId = 2, wireType = "bell_tripline" },
    } })

    assert_nil(DeadwireNetwork.getTile(1, 1, 0))
    assert_not_nil(DeadwireNetwork.getTile(2, 2, 0))
end)

test("an empty or absent payload is survivable", function()
    resetAll()

    server("WireNetworkSync", {})
    server("WireNetworkSync", { wires = {} })
end)

test("wires in already-loaded chunks get their object linked", function()
    resetAll()
    local sq = _makeSquare(1, 1, 0)
    local obj = IsoThumpable.new(getCell(), sq, "deadwire_01_8", false, {})
    obj:getModData()["dw_type"] = "tin_can_tripline"

    server("WireNetworkSync", { wires = {
        { x = 1, y = 1, z = 0, networkId = 1, wireType = "tin_can_tripline", ownerId = "alice" },
    } })

    assert_eq(DeadwireNetwork.getTile(1, 1, 0).isoObject, obj,
        "LoadGridsquare will not fire again for a chunk that is already loaded, "
        .. "so without this those wires never get an isoObject at all")
end)

-----------------------------------------------------------------
suite("EventHandlers: asking for the sync")
-----------------------------------------------------------------

test("a multiplayer client asks on game start", function()
    resetAll()
    _setClient(true)

    Events.OnGameStart:Fire()

    assert_eq(#_sentClient, 1)
    assert_eq(_sentClient[1].cmd, "RequestWireSync")
end)

test("single player asks for nothing", function()
    resetAll()
    _setClient(false)

    Events.OnGameStart:Fire()

    assert_eq(#_sentClient, 0,
        "single player shares one tileIndex between both halves of the mod; "
        .. "there is nobody to ask")
end)

-----------------------------------------------------------------
suite("EventHandlers: ElectricZap (#13, handler ahead of the feature)")
-----------------------------------------------------------------

test("it plays the zap at the given tile", function()
    resetAll()
    _makeSquare(3, 3, 0)

    server("ElectricZap", { x = 3, y = 3, z = 0 })

    assert_eq(_lastWorldSound().name, DeadwireConfig.Sounds.ELEC_ZAP)
end)

test("an unloaded tile is skipped", function()
    resetAll()

    server("ElectricZap", { x = 900, y = 900, z = 0 })

    assert_eq(#_getWorldSounds(), 0)
end)
