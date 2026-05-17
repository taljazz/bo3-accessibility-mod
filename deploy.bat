@echo off
setlocal

:: Use the directory where this bat file lives as the source
set "SRC=%~dp0"
set "BO3=C:\Program Files (x86)\Steam\steamapps\common\Call of Duty Black Ops III 455130"
set "MOD=%BO3%\mods\zm_accessibility"

echo === BO3 Accessibility Mod Deploy ===
echo.

:: Create mod directories if they don't exist
if not exist "%MOD%\scripts\zm\gametypes" (
    echo Creating mod directories...
    mkdir "%MOD%\scripts\zm\gametypes"
)
if not exist "%MOD%\sound\accessibility" (
    mkdir "%MOD%\sound\accessibility"
)

:: Copy GSC scripts
echo Copying scripts...
xcopy "%SRC%scripts\zm\*.gsc" "%MOD%\scripts\zm\" /Y /Q
xcopy "%SRC%scripts\zm\gametypes\*.gsc" "%MOD%\scripts\zm\gametypes\" /Y /Q

:: Copy sound files
echo Copying sound files...
xcopy "%SRC%sound\accessibility" "%MOD%\sound\accessibility" /E /Y /Q

:: Prepare sound-cue assets (12 alias WAVs + zm_mod.csv) into Mod Tools sound_assets
echo.
echo Preparing sound assets...
powershell -ExecutionPolicy Bypass -File "%SRC%tools\prepare_sound_assets.ps1"

:: Run rebuild to link the mod
echo.
echo Running rebuild...
powershell -ExecutionPolicy Bypass -File "%SRC%tools\rebuild.ps1"

echo.
echo Deploy and rebuild complete!
pause
