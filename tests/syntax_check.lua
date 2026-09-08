-- tests/syntax_check.lua
-- Compiles every mod .lua file and reports pass/fail per file (#47).
--
-- Why this exists: tests/run.lua requires six of the fourteen mod files. A
-- syntax error in the other eight is invisible until the game refuses the file
-- at load, with the error going to console.txt where nobody is looking.
--
-- What this does NOT catch: loadfile() parses without executing, so a file-scope
-- call that throws at runtime -- ISBuildingObject:derive() on a nil global, the
-- shape that hid Events.OnPlayerConnect for a release -- compiles clean here.
-- Requiring the file in run.lua is what catches that. Two different gates.

local MOD_LUA = "Contents/mods/Deadwire/42/media/lua"

-- Lua has no directory API. Ask the shell, and accept whichever of the two
-- answers. Finding zero files is a failure, not a pass: a checker that reports
-- green because it looked nowhere is the failure mode this file exists to
-- avoid.
local function list_lua_files(root)
    local commands = {
        'dir /b /s "' .. root:gsub("/", [[\]]) .. [[\*.lua" 2>nul]],
        'find "' .. root .. '" -name "*.lua" -type f 2>/dev/null',
    }
    for _, cmd in ipairs(commands) do
        local files = {}
        local pipe = io.popen(cmd)
        if pipe then
            for line in pipe:lines() do
                line = line:gsub("%s+$", "")
                if line:match("%.lua$") then files[#files + 1] = line end
            end
            pipe:close()
        end
        if #files > 0 then
            table.sort(files)
            return files
        end
    end
    return {}
end

local function short_name(path)
    local normalized = path:gsub("\\", "/")
    return normalized:match("/lua/(.+)$") or normalized
end

print("-- syntax check: " .. MOD_LUA .. " --")

local files = list_lua_files(MOD_LUA)
if #files == 0 then
    print("  ERROR  found no .lua files under " .. MOD_LUA)
    print("         the check did not run; this is not a pass")
    os.exit(1)
end

local failed = 0
for _, path in ipairs(files) do
    local chunk, err = loadfile(path)
    if chunk then
        print("  OK    " .. short_name(path))
    else
        print("  FAIL  " .. short_name(path))
        print("        " .. tostring(err))
        failed = failed + 1
    end
end

print(string.rep("-", 40))
print(string.format("Syntax: %d files, %d failed", #files, failed))
if failed > 0 then os.exit(1) end
