-- Deadwire Config: Constants, wire type definitions, sandbox helpers
-- Shared: runs on both client and server

DeadwireConfig = DeadwireConfig or {}

-- Module name for MP commands
DeadwireConfig.MODULE = "Deadwire"

-- Debug mode (set true for development, false for release)
DeadwireConfig.DEBUG = true

-----------------------------------------------------------
-- Wire Types
-----------------------------------------------------------
DeadwireConfig.WireTypes = {
    TIN_CAN       = "tin_can_tripline",
    REINFORCED    = "reinforced_tripline",
    BELL          = "bell_tripline",
    TANGLEFOOT    = "tanglefoot",
    PULL_ALARM    = "pull_alarm",
    ELECTRIC      = "electric_fence",
    ELECTRIC_BARBED = "electric_barbed",
}

-----------------------------------------------------------
-- Tier Definitions
-----------------------------------------------------------
DeadwireConfig.Tiers = {
    [0] = { "tin_can_tripline" },
    [1] = { "reinforced_tripline", "bell_tripline", "tanglefoot" },
    [2] = { "pull_alarm" },
    [3] = { "electric_fence" },
    [4] = { "electric_barbed" },
}

-----------------------------------------------------------
-- Wire Property Defaults (overridden by SandboxVars)
-----------------------------------------------------------
DeadwireConfig.WireDefaults = {
    tin_can_tripline = {
        health = 50,
        maxSpan = 4,
        soundRadius = 25,
        soundVolume = 60,
        breakOnTrigger = true,
        tier = 0,
    },
    reinforced_tripline = {
        health = 150,
        maxSpan = 8,
        soundRadius = 40,
        soundVolume = 80,
        breakOnTrigger = false,
        cooldownSeconds = 36,
        tier = 1,
    },
    bell_tripline = {
        health = 150,
        maxSpan = 8,
        soundRadius = 60,
        soundVolume = 80,
        breakOnTrigger = false,
        cooldownSeconds = 36,
        tier = 1,
    },
    tanglefoot = {
        health = 100,
        maxSpan = 1,
        tripChance = 40,
        proneDuration = 3.0,
        tier = 1,
    },
}

-----------------------------------------------------------
-- Sound Names
-----------------------------------------------------------
DeadwireConfig.Sounds = {
    TIN_CAN_RATTLE   = "Deadwire_TinCanRattle",
    WIRE_RATTLE      = "Deadwire_WireRattle",
    BELL_RING        = "Deadwire_BellRing",
    ALARM_BELL       = "Deadwire_AlarmBell",
    CAR_HORN         = "Deadwire_CarHorn",
    ELEC_ZAP         = "Deadwire_ElecZap",
}

-----------------------------------------------------------
-- Sandbox Helpers
-----------------------------------------------------------

-- Get a SandboxVars.Deadwire value with fallback default
function DeadwireConfig.getSandbox(key, default)
    if SandboxVars and SandboxVars.Deadwire and SandboxVars.Deadwire[key] ~= nil then
        return SandboxVars.Deadwire[key]
    end
    return default
end

-- Check if a tier is enabled
function DeadwireConfig.isTierEnabled(tier)
    if not DeadwireConfig.getSandbox("EnableMod", true) then
        return false
    end
    local keys = {
        [0] = "EnableTier0",
        [1] = "EnableTier1",
        [2] = "EnableTier2",
        [3] = "EnableTier3",
        [4] = "EnableTier4",
    }
    return DeadwireConfig.getSandbox(keys[tier], true)
end

-----------------------------------------------------------
-- Logging
-----------------------------------------------------------

function DeadwireConfig.debugLog(msg)
    if DeadwireConfig.DEBUG then
        print("[Deadwire] " .. tostring(msg))
    end
end

function DeadwireConfig.log(msg)
    print("[Deadwire] " .. tostring(msg))
end
