-- tests/test_trigger_handlers.lua
-- Tests for the per-wire-type trigger behaviour (client/TriggerHandlers.lua).
--
-- These eight handlers are what a wire actually does when something walks into
-- it, and none of them ran in a test before #47. Two separate sound systems are
-- in play and both matter: PlayWorldSound is the clip a player hears, and
-- getWorldSoundManager():addSound is the noise zombies path towards. A wire
-- that makes one and not the other is either silent or harmless, and the
-- difference is invisible from the code.

local function resetAll()
    _reset()
    _clearCommands()
    _clearSounds()
end

-- Arm a wire and walk something into it, through the real detection path.
local function wireAt(x, y, z, wireType, owner)
    _makeSquare(x, y, z)
    DeadwireNetwork.registerTile(x, y, z, 1, wireType, owner or "alice")
end

local function zombieSteps(x, y, z)
    local zed = _mockZombie(x, y, z)
    Events.OnZombieUpdate:Fire(zed)
    return zed
end

local function playerSteps(x, y, z, username)
    local player = _mockPlayer(x, y, z, username or "bob")
    Events.OnPlayerUpdate:Fire(player)
    return player
end

-----------------------------------------------------------------
suite("TriggerHandlers: registration")
-----------------------------------------------------------------

test("all four wire types have both handlers", function()
    for _, wireType in ipairs({
        "tin_can_tripline", "reinforced_tripline", "bell_tripline", "tanglefoot",
    }) do
        assert_not_nil(DeadwireDetection.zombieHandlers[wireType],
            wireType .. " has no zombie handler, so detection would fall back "
            .. "to the generic noise stub")
        assert_not_nil(DeadwireDetection.playerHandlers[wireType],
            wireType .. " has no player handler")
    end
end)

-----------------------------------------------------------------
suite("TriggerHandlers: the three noisy wires")
-----------------------------------------------------------------

test("a tin can line rattles, calls zombies, and tells the server", function()
    resetAll()
    wireAt(2, 2, 0, "tin_can_tripline")

    zombieSteps(2, 2, 0)

    assert_eq(_lastWorldSound().name, DeadwireConfig.Sounds.TIN_CAN_RATTLE,
        "the clip the player hears")
    assert_eq(#_getSoundCalls(), 1, "the noise zombies walk towards")
    assert_eq(_getSoundCalls()[1].radius, 25)
    assert_eq(_getSoundCalls()[1].volume, 60)

    local sent = _sentClient[1]
    assert_not_nil(sent, "without this the server never breaks the wire")
    assert_eq(sent.cmd, "WireTriggered")
    assert_eq(sent.args.x, 2)
    assert_eq(sent.args.wireType, "tin_can_tripline")
end)

test("a reinforced line uses the wire rattle and carries further", function()
    resetAll()
    wireAt(2, 2, 0, "reinforced_tripline")

    zombieSteps(2, 2, 0)

    assert_eq(_lastWorldSound().name, DeadwireConfig.Sounds.WIRE_RATTLE)
    assert_eq(_getSoundCalls()[1].radius, 40)
end)

test("a bell is the loudest of the three", function()
    resetAll()
    wireAt(2, 2, 0, "bell_tripline")

    zombieSteps(2, 2, 0)

    assert_eq(_lastWorldSound().name, DeadwireConfig.Sounds.BELL_RING)
    assert_eq(_getSoundCalls()[1].radius, 60,
        "the bell's whole reason to exist over reinforced is reach")
end)

test("a player walking into a line sets it off the same way", function()
    resetAll()
    wireAt(2, 2, 0, "bell_tripline")

    playerSteps(2, 2, 0)

    assert_eq(_lastWorldSound().name, DeadwireConfig.Sounds.BELL_RING)
    assert_eq(_sentClient[1].cmd, "WireTriggered")
end)

test("SoundMultiplier scales the zombie-attracting radius", function()
    resetAll()
    SandboxVars.Deadwire.SoundMultiplier = 2.0
    wireAt(2, 2, 0, "tin_can_tripline")

    zombieSteps(2, 2, 0)

    assert_eq(_getSoundCalls()[1].radius, 50)
end)

test("on a multiplayer client the clip is left to the server broadcast", function()
    resetAll()
    _setClient(true)
    wireAt(2, 2, 0, "bell_tripline")

    zombieSteps(2, 2, 0)

    assert_eq(#_getWorldSounds(), 0,
        "playing it here as well as on the broadcast would double every alarm")
    assert_eq(#_getSoundCalls(), 1, "the zombie-AI sound is always local")
    assert_eq(_sentClient[1].cmd, "WireTriggered")
end)

-----------------------------------------------------------------
suite("TriggerHandlers: tanglefoot against zombies")
-----------------------------------------------------------------

test("tanglefoot is silent", function()
    resetAll()
    wireAt(2, 2, 0, "tanglefoot")

    zombieSteps(2, 2, 0)

    assert_eq(#_getWorldSounds(), 0, "silent area denial is the entire point")
    assert_eq(#_getSoundCalls(), 0)
end)

test("a passing roll puts the zombie down", function()
    resetAll()
    wireAt(2, 2, 0, "tanglefoot")
    _setZombRand(0)   -- 0 < 40

    local zed = zombieSteps(2, 2, 0)

    assert_true(zed._knockedDown)
end)

test("a failing roll leaves it standing", function()
    resetAll()
    wireAt(2, 2, 0, "tanglefoot")
    _setZombRand(50)  -- 50 < 40 is false

    local zed = zombieSteps(2, 2, 0)

    assert_false(zed._knockedDown,
        "a 40 percent trap that trips everything is a 100 percent trap")
end)

test("TanglefootTripChance moves the line", function()
    resetAll()
    SandboxVars.Deadwire.TanglefootTripChance = 90
    wireAt(2, 2, 0, "tanglefoot")
    _setZombRand(50)  -- 50 < 90

    local zed = zombieSteps(2, 2, 0)

    assert_true(zed._knockedDown)
end)

test("a crawler is left alone by default", function()
    resetAll()
    wireAt(2, 2, 0, "tanglefoot")
    _setZombRand(0)
    local crawler = _mockCrawler(2, 2, 0)

    Events.OnZombieUpdate:Fire(crawler)

    assert_false(crawler._knockedDown,
        "something already on the floor cannot be tripped")
    assert_eq(#_sentClient, 0,
        "the skipped crawler returns before notifying the server at all")
end)

test("TanglefootAffectsCrawlers=true trips them too", function()
    resetAll()
    SandboxVars.Deadwire.TanglefootAffectsCrawlers = true
    wireAt(2, 2, 0, "tanglefoot")
    _setZombRand(0)
    local crawler = _mockCrawler(2, 2, 0)

    Events.OnZombieUpdate:Fire(crawler)

    assert_true(crawler._knockedDown)
end)

test("the server is told even when the roll failed", function()
    resetAll()
    wireAt(2, 2, 0, "tanglefoot")
    _setZombRand(50)

    zombieSteps(2, 2, 0)

    assert_eq(_sentClient[1].cmd, "WireTriggered",
        "the trigger is what degrades camouflage; a missed trip is still a "
        .. "zombie standing in the wire")
end)

-----------------------------------------------------------------
suite("TriggerHandlers: tanglefoot against players")
-----------------------------------------------------------------

test("a player stumbles", function()
    resetAll()
    wireAt(2, 2, 0, "tanglefoot")

    local player = playerSteps(2, 2, 0)

    assert_eq(player._bumpType, "stagger")
    assert_false(player._variables.BumpDone)
    assert_true(player._variables.BumpFall)
    assert_eq(player._variables.BumpFallType, "pushedFront")
end)

test("PlayerTripStumble=false leaves them on their feet", function()
    resetAll()
    SandboxVars.Deadwire.PlayerTripStumble = false
    wireAt(2, 2, 0, "tanglefoot")

    local player = playerSteps(2, 2, 0)

    assert_nil(player._bumpType)
end)

test("the default trip does five points of foot damage", function()
    resetAll()
    wireAt(2, 2, 0, "tanglefoot")

    local player = playerSteps(2, 2, 0)

    assert_eq(_getBodyPartDamage(player, BodyPartType.Foot_L), 5)
end)

test("PlayerTripDamage=0 does none", function()
    resetAll()
    SandboxVars.Deadwire.PlayerTripDamage = 0
    wireAt(2, 2, 0, "tanglefoot")

    local player = playerSteps(2, 2, 0)

    assert_eq(_getBodyPartDamage(player, BodyPartType.Foot_L), 0,
        "a zero here has to mean zero, not the default")
end)

test("a stumbling player is not knocked down like a zombie", function()
    resetAll()
    wireAt(2, 2, 0, "tanglefoot")
    _setZombRand(0)

    local player = playerSteps(2, 2, 0)

    assert_nil(player._knockedDown,
        "the trip roll is the zombie branch; a player always stumbles")
end)
