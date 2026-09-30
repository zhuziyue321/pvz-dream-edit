@echo off
REM ============================================================
REM  Debug channel - normal play mode
REM
REM  Launches the game with the debug channel enabled and captures
REM  ALL stdout/stderr into one log file.
REM
REM  How to use:
REM    1. run this file
REM    2. play normally (enter a level, place plants, etc.)
REM    3. press F10 at any moment to dump a state snapshot
REM    4. quit the game
REM    5. send back debug_channel_log.txt
REM
REM  Override the engine path with:  set GODOT=D:\path\godot.exe
REM ============================================================
setlocal
if "%GODOT%"=="" set GODOT=C:\Users\a a\Desktop\Godot_v4.6.2-stable_win64.exe
set PROJ=%~dp0..
set LOG=%PROJ%\debug_channel_log.txt

echo [debug channel] engine : %GODOT%
echo [debug channel] project: %PROJ%
echo [debug channel] log    : %LOG%
echo.
echo Play the game, press F10 for a snapshot, then close the window.
echo.

"%GODOT%" --path "%PROJ%" -- --debug-channel > "%LOG%" 2>&1

echo.
echo [debug channel] finished. Send back:
echo   %LOG%
echo The report file path is printed inside that log.
pause
