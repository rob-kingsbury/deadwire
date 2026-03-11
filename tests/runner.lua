-- tests/runner.lua
-- Minimal test framework. No external dependencies.

local _pass = 0
local _fail = 0
local _suite = ""

function suite(name)
    _suite = name
    print("\n-- " .. name .. " --")
end

function test(name, fn)
    local ok, err = pcall(fn)
    if ok then
        print("  PASS  " .. name)
        _pass = _pass + 1
    else
        print("  FAIL  " .. name)
        print("        " .. tostring(err))
        _fail = _fail + 1
    end
end

function assert_eq(a, b, msg)
    if a ~= b then
        error(
            (msg or "assert_eq") ..
            ": expected [" .. tostring(b) .. "], got [" .. tostring(a) .. "]",
            2
        )
    end
end

function assert_ne(a, b, msg)
    if a == b then
        error(
            (msg or "assert_ne") .. ": expected not [" .. tostring(b) .. "]",
            2
        )
    end
end

function assert_true(v, msg)
    if not v then
        error((msg or "assert_true") .. ": expected true, got " .. tostring(v), 2)
    end
end

function assert_false(v, msg)
    if v then
        error((msg or "assert_false") .. ": expected false, got " .. tostring(v), 2)
    end
end

function assert_nil(v, msg)
    if v ~= nil then
        error((msg or "assert_nil") .. ": expected nil, got " .. tostring(v), 2)
    end
end

function assert_not_nil(v, msg)
    if v == nil then
        error((msg or "assert_not_nil") .. ": expected non-nil value", 2)
    end
end

function assert_gte(a, b, msg)
    if not (a >= b) then
        error(
            (msg or "assert_gte") ..
            ": expected [" .. tostring(a) .. "] >= [" .. tostring(b) .. "]",
            2
        )
    end
end

function results()
    print("\n" .. string.rep("-", 40))
    print(string.format("Results: %d passed, %d failed", _pass, _fail))
    if _fail > 0 then os.exit(1) end
end
