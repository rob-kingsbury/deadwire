@echo off
set LUA_EXE=C:\Users\roban\AppData\Local\Programs\Lua\bin\lua.exe
if not exist "%LUA_EXE%" (
    echo ERROR: Lua not found at %LUA_EXE%
    exit /b 1
)
"%LUA_EXE%" tests/run.lua
