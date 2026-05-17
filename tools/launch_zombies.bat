@echo off
setlocal EnableDelayedExpansion
title BO3 Accessibility - Zombies Launcher

:: --- Paths ---
set "STEAM=C:\Program Files (x86)\Steam\steam.exe"
set "TOOLSMOD=C:\Program Files (x86)\Steam\steamapps\common\Call of Duty Black Ops III 455130\mods\zm_accessibility"
set "GAMEMOD=C:\Program Files (x86)\Steam\steamapps\common\Call of Duty Black Ops III\mods\zm_accessibility"

echo =============================================
echo   BO3 Zombies Accessibility - Map Launcher
echo =============================================
echo.

:: --- Make sure the built mod is where the RETAIL game loads it ---
:: Mod Tools build into the "455130" folder, but the game (app 311210)
:: loads mods from the base-game mods folder. Mirror it across.
if not exist "%TOOLSMOD%\zone\zm_mod.ff" (
    echo ERROR: Mod is not built yet.
    echo Run deploy.bat first, then run this launcher again.
    echo.
    pause
    exit /b 1
)
echo Copying the built mod into the game's mods folder...
if not exist "%GAMEMOD%" mkdir "%GAMEMOD%"
xcopy "%TOOLSMOD%" "%GAMEMOD%" /E /I /Y /Q >nul
echo Done.
echo.

:: --- Numbered, screen-reader-friendly map menu ---
echo Choose a map by typing its number and pressing Enter:
echo.
echo   Base maps:
echo     1.  Shadows of Evil
echo     2.  The Giant
echo     3.  Der Eisendrache
echo     4.  Zetsubou No Shima
echo     5.  Gorod Krovi
echo     6.  Revelations
echo.
echo   Zombies Chronicles:
echo     7.  Nacht der Untoten
echo     8.  Verruckt
echo     9.  Shi No Numa
echo     10. Kino der Toten
echo     11. Ascension
echo     12. Shangri-La
echo     13. Moon
echo     14. Origins
echo.
set "MAP="
set /p "SEL=Map number (1-14): "

if "%SEL%"=="1"  set "MAP=zm_zod"
if "%SEL%"=="2"  set "MAP=zm_factory"
if "%SEL%"=="3"  set "MAP=zm_castle"
if "%SEL%"=="4"  set "MAP=zm_island"
if "%SEL%"=="5"  set "MAP=zm_stalingrad"
if "%SEL%"=="6"  set "MAP=zm_genesis"
if "%SEL%"=="7"  set "MAP=zm_prototype"
if "%SEL%"=="8"  set "MAP=zm_asylum"
if "%SEL%"=="9"  set "MAP=zm_sumpf"
if "%SEL%"=="10" set "MAP=zm_theater"
if "%SEL%"=="11" set "MAP=zm_cosmodrome"
if "%SEL%"=="12" set "MAP=zm_temple"
if "%SEL%"=="13" set "MAP=zm_moon"
if "%SEL%"=="14" set "MAP=zm_tomb"

if "%MAP%"=="" (
    echo.
    echo Invalid choice "%SEL%". Please run the launcher again and pick 1 to 14.
    echo.
    pause
    exit /b 1
)

echo.
echo Selected map: %MAP%
echo.
echo REMINDER: Start the TTS bridge in a separate window (launch_bridge.bat)
echo and make sure NVDA is running, so in-game announcements are spoken.
echo.
echo Launching Black Ops 3 with the accessibility mod...
start "" "%STEAM%" -applaunch 311210 +set fs_game zm_accessibility +devmap %MAP%

echo.
echo If the game opens but the mod does not load, use Treyarch's
echo Mod Tools launcher (modtools_launcher.bat) once to register the mod.
echo.
pause
