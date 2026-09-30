@echo off
REM ============================================================
REM  Debug channel - automatic level run (headless)
REM
REM  Boots the game, loads a level by itself, runs it for N game
REM  seconds, probes the live state and exits. Nothing to click.
REM
REM  The user data dir is redirected to a temp folder, so your real
REM  saves are NOT touched.
REM
REM  Optional:  set SECONDS=90
REM ============================================================
setlocal
if "%GODOT%"=="" set GODOT=C:\Users\a a\Desktop\Godot_v4.6.2-stable_win64.exe
if "%SECONDS%"=="" set SECONDS=45
set PROJ=%~dp0..
set LOG=%PROJ%\debug_channel_auto_log.txt
set USERDIR=%TEMP%\pvz_debug_userdir

if exist "%USERDIR%" rmdir /S /Q "%USERDIR%"
mkdir "%USERDIR%" 2>nul

echo [debug channel] headless auto-level run, %SECONDS% game seconds
echo [debug channel] log: %LOG%
echo.

set APPDATA=%USERDIR%
"%GODOT%" --headless --path "%PROJ%" -- --debug-channel-level --debug-channel-seconds=%SECONDS% > "%LOG%" 2>&1

echo.
echo [debug channel] finished. Send back:
echo   %LOG%
pause
