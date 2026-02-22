-- Deadwire LootDistribution: Add bells to loot tables
-- Server: runs via OnPreDistributionMerge (fires once at game start)

require "Deadwire/Config"

local function getSpawnChance()
    local rate = DeadwireConfig.getSandbox("BellSpawnRate", 3)
    -- enum: 1=Rare, 2=Moderate, 3=Common, 4=Abundant
    local chances = { [1] = 2, [2] = 6, [3] = 12, [4] = 20 }
    return chances[rate] or 12
end

local function preDistributionMerge()
    if not DeadwireConfig.getSandbox("EnableMod", true) then return end

    local chance = getSpawnChance()

    -- Distribution name -> spawn chance multiplier
    local distributions = {
        "FarmTools",
        "BarnTools",
        "ToolStoreTools",
        "GardenStoreTools",
        "SchoolLockers",
        "OfficeDeskHome",
        "ChurchMisc",
    }

    for _, distName in ipairs(distributions) do
        if ProceduralDistributions.list[distName] then
            table.insert(ProceduralDistributions.list[distName].items, "Base.Bell")
            table.insert(ProceduralDistributions.list[distName].items, chance)
        end
    end

    DeadwireConfig.log("LootDistribution: bells added to " .. #distributions .. " tables (chance=" .. chance .. ")")
end

Events.OnPreDistributionMerge.Add(preDistributionMerge)
DeadwireConfig.log("LootDistribution initialized (server)")
