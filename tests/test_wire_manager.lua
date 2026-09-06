-- tests/test_wire_manager.lua
-- Tests for WireManager persistence and the join-sync payload.
--
-- These exist because #34 was invisible for the life of the mod: camouflage
-- lived only in the in-memory WireNetwork entry, was never written to the save,
-- and every reload silently stripped it from every wire. Nothing failed, so
-- nothing caught it.
--
-- No PZ world is needed here: saveWire, saveCamo, loadAll and
-- buildSyncPayload all work against the ModData stub.

suite("WireManager: camouflage persistence (#34)")

test("a freshly saved wire is stored uncamouflaged", function()
    _reset()
    DeadwireWireManager.saveWire(4, 5, 0, 7, "tin_can_tripline", "alice")

    DeadwireWireManager.loadAll()
    local wire = DeadwireNetwork.getTile(4, 5, 0)
    assert_not_nil(wire, "wire should load back")
    assert_false(wire.camouflaged, "a new wire is not camouflaged")
    assert_eq(wire.camoDurability, 0)
end)

test("camouflage survives a save and reload", function()
    _reset()
    DeadwireWireManager.saveWire(4, 5, 0, 7, "tin_can_tripline", "alice")
    DeadwireWireManager.saveCamo(4, 5, 0, true, 80)

    DeadwireWireManager.loadAll()   -- clears the network and rebuilds from save

    local wire = DeadwireNetwork.getTile(4, 5, 0)
    assert_not_nil(wire, "wire should load back")
    assert_true(wire.camouflaged, "camo must survive a reload")
    assert_eq(wire.camoDurability, 80, "durability must survive with it")
end)

test("a reloaded camouflaged wire is back in the camo index", function()
    _reset()
    DeadwireWireManager.saveWire(4, 5, 0, 7, "tin_can_tripline", "alice")
    DeadwireWireManager.saveCamo(4, 5, 0, true, 80)
    DeadwireWireManager.loadAll()

    -- CamoVisibility and CamoDegradation both iterate this, not tileIndex.
    local camo = DeadwireNetwork.getCamoTiles()
    local key = DeadwireNetwork.tileKey(4, 5, 0)
    assert_not_nil(camo[key], "reloaded camo wire must be in the camo index")
end)

test("removing camo persists too", function()
    _reset()
    DeadwireWireManager.saveWire(4, 5, 0, 7, "tin_can_tripline", "alice")
    DeadwireWireManager.saveCamo(4, 5, 0, true, 80)
    DeadwireWireManager.saveCamo(4, 5, 0, false, 0)

    DeadwireWireManager.loadAll()

    local wire = DeadwireNetwork.getTile(4, 5, 0)
    assert_false(wire.camouflaged, "camo removal must survive a reload as well")
end)

test("saveCamo on a tile with no saved wire is a no-op, not an error", function()
    _reset()
    DeadwireWireManager.saveCamo(99, 99, 0, true, 50)
    DeadwireWireManager.loadAll()
    assert_nil(DeadwireNetwork.getTile(99, 99, 0), "no wire should have been invented")
end)

suite("WireManager: join sync payload (#33)")

test("payload carries every saved wire", function()
    _reset()
    DeadwireWireManager.saveWire(1, 1, 0, 1, "tin_can_tripline", "alice")
    DeadwireWireManager.saveWire(2, 2, 0, 2, "bell_tripline", "bob")

    local list = DeadwireWireManager.buildSyncPayload()
    assert_eq(#list, 2, "both wires should be in the payload")
end)

test("payload carries camouflage state", function()
    _reset()
    DeadwireWireManager.saveWire(1, 1, 0, 1, "tin_can_tripline", "alice")
    DeadwireWireManager.saveCamo(1, 1, 0, true, 65)

    local list = DeadwireWireManager.buildSyncPayload()
    assert_eq(#list, 1)
    assert_true(list[1].camouflaged, "a joining client must be told the wire is hidden")
    assert_eq(list[1].camoDurability, 65)
end)

test("payload is empty when nothing is saved", function()
    _reset()
    assert_eq(#DeadwireWireManager.buildSyncPayload(), 0)
end)

suite("WireManager: a missing sprite fails loudly (#39)")

test("there is no FALLBACK_SPRITE to substitute", function()
    assert_nil(DeadwireConfig.FALLBACK_SPRITE,
        "a vanilla wall frame standing in for a trip wire looked like it worked")
end)

test("createWire refuses a wire type with no sprite", function()
    _reset()
    local sq = _makeSquare(70, 70, 0)

    -- A type with defaults but no Sprites entry: exactly the shape a new wire
    -- type takes on the day someone adds it and forgets the sprite table.
    DeadwireConfig.WireDefaults["spriteless_test"] = { health = 10, tier = 0 }

    local obj = DeadwireWireManager.createWire(sq, "spriteless_test", "alice", 99)

    DeadwireConfig.WireDefaults["spriteless_test"] = nil

    assert_nil(obj, "no sprite must mean no wire, not a wall frame")
    assert_nil(DeadwireNetwork.getTile(70, 70, 0), "and nothing registered")
end)

test("createWire still works for a real type", function()
    _reset()
    local sq = _makeSquare(71, 71, 0)

    local obj = DeadwireWireManager.createWire(sq, "tin_can_tripline", "alice", 1)

    assert_not_nil(obj, "a declared type must still place")
    assert_not_nil(DeadwireNetwork.getTile(71, 71, 0), "and register")
end)

suite("WireManager: run-mode guard on load (#35)")

test("the authoritative side loads the saved wires", function()
    _reset()                       -- isClient() false: single player or dedicated server
    DeadwireWireManager.saveWire(80, 80, 0, 1, "tin_can_tripline", "alice")

    Events.OnInitGlobalModData:Fire(false)

    assert_not_nil(DeadwireNetwork.getTile(80, 80, 0), "the save is the source of truth here")
end)

test("a multiplayer client does not load from its own empty save table", function()
    _reset()
    DeadwireWireManager.saveWire(81, 81, 0, 1, "tin_can_tripline", "alice")
    DeadwireNetwork.registerTile(81, 81, 0, 1, "tin_can_tripline", "alice")
    _setClient(true)

    Events.OnInitGlobalModData:Fire(false)

    -- server/ is a load-order directory, not a guard: this file runs on clients
    -- too, where the real wire list arrives from RequestWireSync instead.
    assert_nil(DeadwireNetwork.getTile(81, 81, 0),
        "the client still clears, so joining a second server carries nothing over")
    _setClient(false)
end)
