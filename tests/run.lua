-- tests/run.lua
-- Entry point for the Deadwire test suite.
-- Run from the repo root: lua tests/run.lua

-- Set up package.path so require "Deadwire/X" resolves to the mod files
local base = "Contents/mods/Deadwire/42/media/lua"
package.path = base .. "/shared/?.lua;"
             .. base .. "/client/?.lua;"
             .. base .. "/server/?.lua;"
             .. package.path

-- Load stubs FIRST (defines all PZ API globals before any mod code runs)
dofile("tests/stubs.lua")

-- Load test framework
dofile("tests/runner.lua")

-- Load Deadwire modules (order matters: shared first, then client, then server)
require "Deadwire/Config"
require "Deadwire/WireNetwork"
require "Deadwire/Detection"     -- registers Events.OnZombieUpdate / OnPlayerUpdate
require "Deadwire/WireManager"   -- registers Events.OnInitGlobalModData / LoadGridsquare
require "Deadwire/ServerCommands" -- registers Events.OnClientCommand

-- Run test files
dofile("tests/test_config.lua")
dofile("tests/test_wire_network.lua")
dofile("tests/test_detection.lua")
dofile("tests/test_server_commands.lua")

-- Print final results (exits with code 1 if any failures)
results()
