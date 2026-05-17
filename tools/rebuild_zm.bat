@echo off
cd /d "C:\Program Files (x86)\Steam\steamapps\common\Call of Duty Black Ops III 455130"
set "TA_GAME_PATH=C:\Program Files (x86)\Steam\steamapps\common\Call of Duty Black Ops III 455130\"
set "TA_TOOLS_PATH=C:\Program Files (x86)\Steam\steamapps\common\Call of Duty Black Ops III 455130\"
set "TA_LOCAL_ASSET_CACHE=C:\Program Files (x86)\Steam\steamapps\common\Call of Duty Black Ops III 455130\share\assetconvert\"

echo === Starting GDTDB Update === >> "%~dp0build_log.txt" 2>&1
gdtdb\gdtdb.exe /update >> "%~dp0build_log.txt" 2>&1
echo GDTDB Exit: %ERRORLEVEL% >> "%~dp0build_log.txt" 2>&1

echo === Linking zm_mod === >> "%~dp0build_log.txt" 2>&1
bin\linker_modtools.exe -language english -fs_game zm_accessibility -modsource zm_mod >> "%~dp0build_log.txt" 2>&1
echo zm_mod Exit: %ERRORLEVEL% >> "%~dp0build_log.txt" 2>&1

echo === Linking core_mod === >> "%~dp0build_log.txt" 2>&1
bin\linker_modtools.exe -language english -fs_game zm_accessibility -modsource core_mod >> "%~dp0build_log.txt" 2>&1
echo core_mod Exit: %ERRORLEVEL% >> "%~dp0build_log.txt" 2>&1

echo === DONE === >> "%~dp0build_log.txt" 2>&1
