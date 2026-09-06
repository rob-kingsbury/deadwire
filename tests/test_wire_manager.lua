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
