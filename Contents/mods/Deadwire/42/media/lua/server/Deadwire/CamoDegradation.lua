-- Deadwire CamoDegradation: Server-side rain-based camouflage durability loss
-- Server: EveryTenMinutes — checks rain strength and degrades all camouflaged wires.
--
-- Trigger-based degradation (each wire trigger) is handled in
-- ServerCommands.lua WireTriggered handler — not here.
--
-- Degradation model:
--   - Rain strength 0.0-0.8: degrade = floor(baseRate * rainStrength)
--   - Rain strength 0.8+:    degrade = floor(baseRate * stormMult)
--   - When durability hits 0: camo removed, WireCamouflaged broadcast to all clients
--
-- NOTE: Climate.GetInstance():getRainStrength() — verify API name in-game.
--       Alternative: getWorld():getWeather():getRainStrength()

require "Deadwire/Config"
require "Deadwire/WireNetwork"

-----------------------------------------------------------
-- Get current rain strength (0.0 = dry, 1.0+ = heavy rain)
-----------------------------------------------------------

local function getRainStrength()
    -- Try Climate API (primary B42 weather system)
    if Climate and Climate.GetInstance then
        local climate = Climate.GetInstance()
        if climate and climate.getRainStrength then
            return climate:getRainStrength() or 0
        end
    end
    -- Fallback: not raining if API unavailable
    return 0
end

-----------------------------------------------------------
-- EveryTenMinutes: apply rain degradation to all camo wires
-----------------------------------------------------------

local function onEveryTenMinutes()
    if not DeadwireConfig.getSandbox("EnableCamouflage", true) then return end

    local rainStrength = getRainStrength()
    if rainStrength <= 0 then return end

    local baseRate    = DeadwireConfig.getSandbox("CamoRainDegradeRate",  5)
    local stormMult   = DeadwireConfig.getSandbox("CamoStormMultiplier",  2.0)
    local STORM_THRESHOLD = 0.8

    local effective
    if rainStrength >= STORM_THRESHOLD then
        effective = math.floor(baseRate * stormMult)
    else
        effective = math.floor(baseRate * rainStrength)
    end

    if effective <= 0 then return end

    -- Collect expired tiles separately — avoids modifying table mid-iteration
    local toRemove = {}
    local camoTiles = DeadwireNetwork.getCamoTiles()

    for key, wire in pairs(camoTiles) do
        local newDur = (wire.camoDurability or 0) - effective
        if newDur <= 0 then
            table.insert(toRemove, { x = wire.x, y = wire.y, z = wire.z })
        else
            wire.camoDurability = newDur
        end
    end

    for _, pos in ipairs(toRemove) do
        DeadwireNetwork.setCamouflaged(pos.x, pos.y, pos.z, false, 0)
        sendServerCommand(DeadwireConfig.MODULE, "WireCamouflaged", {
            x          = pos.x,
            y          = pos.y,
            z          = pos.z,
            camouflaged = false,
            durability  = 0,
        })
        DeadwireConfig.debugLog("CamoDegradation: rain expired camo at "
            .. pos.x .. "," .. pos.y .. "," .. pos.z)
    end

    if #toRemove > 0 then
        DeadwireConfig.log("CamoDegradation: " .. #toRemove
            .. " wire(s) lost camouflage from rain (strength=" .. rainStrength .. ")")
    end
end

Events.EveryTenMinutes.Add(onEveryTenMinutes)
DeadwireConfig.log("CamoDegradation initialized (server)")
