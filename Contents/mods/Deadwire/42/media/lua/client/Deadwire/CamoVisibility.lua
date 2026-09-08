-- Deadwire CamoVisibility: per-client alpha and outline for placed wires
-- Client: reads the local player's own skill, faction and ownership.
--
-- Two jobs, both visual-only and both per-client. Server state is never
-- touched, so nothing here can desync anything.
--
--   1. Camouflaged wires fade by the viewer's Foraging level and distance.
--   2. The owner, and anyone in their faction, sees an outline on every wire
--      they own -- camouflaged or not (#29). You know where you put your own
--      trap, and tanglefoot sits 6px off the ground line and reads as a
--      scribble on grass, so the art does not have to carry that load.
--
-- Runs on OnTick with a 60-tick throttle (~1s at 60fps).
--
-- The skill is PlantScavenging (shown in-game as "Foraging"). Perks.Foraging
-- is NOT a real enum member: reading it yields nil, getPerkLevel(nil) returns
-- 0, and every player is permanently at level 0, so camouflaged wires were
-- invisible to absolutely everyone. Verified against 42.20 (Issue #17).
--
-- Detection scaling (all thresholds configurable via SandboxVars):
--   level 0-2  -> alpha 0.0  (invisible, trips it blind)
--   level 3-4  -> alpha 0.15 (faint shimmer, close range only)
--   level 5-6  -> alpha 0.4  (semi-visible, moderate range)
--   level 7+   -> alpha 0.8  (clear + orange outline)

require "Deadwire/Config"
require "Deadwire/WireNetwork"

local TICK_INTERVAL = 60   -- update once per second at 60fps
local tickCounter   = 0

local MAX_RANGE = 20       -- skip tiles further than this (Chebyshev distance)

-- Outline colour per wire type, so a perimeter is readable at a glance without
-- walking up to every tile. Deliberately none of them is the orange the camo
-- detection branch uses: that one means "somebody else's wire, and you spotted
-- it", which is a different fact about a different wire.
local OWNER_OUTLINE_COL = {
    tin_can_tripline    = { 0.95, 0.85, 0.30 },   -- pale yellow, twine and cans
    reinforced_tripline = { 0.45, 0.70, 1.00 },   -- steel blue
    bell_tripline       = { 1.00, 0.75, 0.25 },   -- brass
    tanglefoot          = { 0.40, 0.90, 0.40 },   -- green, it lives in the grass
}
local OWNER_OUTLINE_FALLBACK = { 1.00, 1.00, 1.00 }
local CAMO_SPOTTED_COL       = { 1.00, 0.50, 0.00 }
local OUTLINE_ALPHA          = 0.5

-----------------------------------------------------------
-- Compute alpha + outline flag for a single camouflaged wire
-----------------------------------------------------------

local function getVisibility(skillLevel, dist, isOwner, adminBypass)
    -- Owner always sees their own wires (configurable)
    if isOwner and DeadwireConfig.getSandbox("CamoVisibleToOwner", true) then
        return 1.0, false
    end

    -- Admins bypass camo entirely (configurable)
    if adminBypass and DeadwireConfig.getSandbox("AdminBypassCamo", true) then
        return 1.0, false
    end

    -- Skill-based visibility (thresholds + detection ranges)
    local fullLevel = DeadwireConfig.getSandbox("CamoDetectLevelFull", 7)
    local midLevel  = DeadwireConfig.getSandbox("CamoDetectLevelMid",  5)
    local lowLevel  = DeadwireConfig.getSandbox("CamoDetectLevelLow",  3)
    local fullRange = DeadwireConfig.getSandbox("CamoDetectRangeFull", 15)
    local midRange  = DeadwireConfig.getSandbox("CamoDetectRangeMid",   8)
    local lowRange  = DeadwireConfig.getSandbox("CamoDetectRangeLow",   3)

    if skillLevel >= fullLevel and dist <= fullRange then
        return 0.8, true   -- clear + orange outline
    end
    if skillLevel >= midLevel and dist <= midRange then
        return 0.4, false  -- semi-visible
    end
    if skillLevel >= lowLevel and dist <= lowRange then
        return 0.15, false -- faint shimmer
    end
    return 0.0, false      -- invisible
end

-----------------------------------------------------------
-- Outline bookkeeping
--
-- Only ever turn an outline off on a wire this module turned on. Reaching in
-- and clearing the flag on every wire in range each second would fight anything
-- else that ever highlights an object, for no gain.
-----------------------------------------------------------

local function setOutline(wire, obj, col)
    if col then
        obj:setOutlineHighlight(true)
        obj:setOutlineHighlightCol(col[1], col[2], col[3], OUTLINE_ALPHA)
        wire.dwOutlined = true
    elseif wire.dwOutlined then
        obj:setOutlineHighlight(false)
        wire.dwOutlined = false
    end
end

-- Is this wire mine, or my group's? ownerId is a username, because the owner
-- may be offline with no IsoPlayer to compare against, which is the overload
-- Faction.isInSameFaction(IsoPlayer, String) is for.
local function isFriendlyWire(wire, username, player)
    if not wire.ownerId then return false end
    if wire.ownerId == username then return true end
    return Faction.isInSameFaction(player, wire.ownerId)
end

-----------------------------------------------------------
-- OnTick: throttled alpha and outline update
-----------------------------------------------------------

local function onTick()
    tickCounter = tickCounter + 1
    if tickCounter < TICK_INTERVAL then return end
    tickCounter = 0

    local camoOn    = DeadwireConfig.getSandbox("EnableCamouflage", true)
    local outlineOn = DeadwireConfig.getSandbox("OwnerWireOutline", true)
    if not camoOn and not outlineOn then return end

    local player = getPlayer()
    if not player then return end

    local username   = player:getUsername() or ""
    local skillLevel = player:getPerkLevel(Perks.PlantScavenging)
    local adminBypass = isAdmin() or false

    local px = math.floor(player:getX())
    local py = math.floor(player:getY())
    local pz = math.floor(player:getZ())

    -- Every wire, not just the camouflaged ones: the owner outline applies to
    -- the whole perimeter. This walks the same table detection reads, once a
    -- second, behind a floor test and a box test.
    for key, wire in pairs(DeadwireNetwork.getAllTiles()) do
        if wire.z == pz then
            local dx = math.abs(wire.x - px)
            local dy = math.abs(wire.y - py)
            if dx <= MAX_RANGE and dy <= MAX_RANGE then
                -- A wire whose IsoThumpable has not arrived yet used to be
                -- skipped every second forever, leaving it at full alpha with
                -- the player believing it was hidden. Look it up here instead;
                -- once found it is cached on the entry (#41).
                local obj = wire.isoObject
                    or DeadwireNetwork.relinkIsoObject(wire.x, wire.y, wire.z)
                if obj then
                    local dist    = math.sqrt(dx * dx + dy * dy)
                    local mine    = isFriendlyWire(wire, username, player)
                    local spotted = false

                    -- Alpha is only ever touched on camouflaged wires. A plain
                    -- wire is left exactly as the engine drew it.
                    if camoOn and wire.camouflaged then
                        local alpha
                        alpha, spotted = getVisibility(
                            skillLevel, dist, wire.ownerId == username, adminBypass)
                        obj:setAlphaAndTarget(alpha)
                    end

                    if outlineOn and mine then
                        setOutline(wire, obj,
                            OWNER_OUTLINE_COL[wire.wireType] or OWNER_OUTLINE_FALLBACK)
                    elseif spotted then
                        setOutline(wire, obj, CAMO_SPOTTED_COL)
                    else
                        setOutline(wire, obj, nil)
                    end
                end
            end
        end
    end
end

Events.OnTick.Add(onTick)
DeadwireConfig.log("CamoVisibility initialized (client)")
