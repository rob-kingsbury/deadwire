-- tests/pzstub/TimedActions/ISBaseTimedAction.lua
-- Stands in for the vanilla class of the same name, which lives in the game's
-- shared/ tree and so is not on our package.path.
--
-- It is a file rather than a global in stubs.lua because WireActions.lua does
-- `require "TimedActions/ISBaseTimedAction"`, and a require has to resolve to
-- something. That require failing is exactly the shape #47 is about: it throws
-- at load and silently kills every line below it in the file.
--
-- Mirrors ISBaseObject:derive -- a fresh table whose __index is the parent, so
-- methods inherit and fields do not.

ISBaseTimedAction = ISBaseTimedAction or {}

function ISBaseTimedAction:derive(name)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.Type = name
    return o
end

function ISBaseTimedAction:new(character)
    local o = setmetatable({}, self)
    self.__index = self
    o.character = character
    -- Recorded so a test can assert the action actually ran to completion
    -- rather than merely being constructed.
    o._performed = false
    o._stopped   = false
    o._anim      = nil
    return o
end

function ISBaseTimedAction:setActionAnim(anim) self._anim = anim end
function ISBaseTimedAction:perform()          self._performed = true end
function ISBaseTimedAction:stop()             self._stopped   = true end
function ISBaseTimedAction:isValid()          return true end
function ISBaseTimedAction:update()           end
function ISBaseTimedAction:start()            end

return ISBaseTimedAction
