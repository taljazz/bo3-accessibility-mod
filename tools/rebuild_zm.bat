@echo off
cd /d "C:\Program Files (x86)\Steam\steamapps\common\Call of Duty Black Ops III"
set "TA_GAME_PATH=C:\Program Files (x86)\Steam\steamapps\common\Call of Duty Black Ops III\"
set "TA_TOOLS_PATH=C:\Program Files (x86)\Steam\steamapps\common\Call of Duty Black Ops III\"
set "TA_LOCAL_ASSET_CACHE=C:\Program Files (x86)\Steam\steamapps\common\Call of Duty Black Ops III\share\assetconvert\"

echo === Starting GDTDB Update === >> "C:\Coding Projects\bo3 mod\build_log.txt" 2>&1
gdtdb\gdtdb.exe /update >> "C:\Coding Projects\bo3 mod\build_log.txt" 2>&1
echo GDTDB Exit: %ERRORLEVEL% >> "C:\Coding Projects\bo3 mod\build_log.txt" 2>&1

echo === Linking zm_mod === >> "C:\Coding Projects\bo3 mod\build_log.txt" 2>&1
bin\linker_modtools.exe -language english -fs_game zm_accessibility -modsource zm_mod >> "C:\Coding Projects\bo3 mod\build_log.txt" 2>&1
echo zm_mod Exit: %ERRORLEVEL% >> "C:\Coding Projects\bo3 mod\build_log.txt" 2>&1

echo === Linking core_mod === >> "C:\Coding Projects\bo3 mod\build_log.txt" 2>&1
bin\linker_modtools.exe -language english -fs_game zm_accessibility -modsource core_mod >> "C:\Coding Projects\bo3 mod\build_log.txt" 2>&1
echo core_mod Exit: %ERRORLEVEL% >> "C:\Coding Projects\bo3 mod\build_log.txt" 2>&1

echo === DONE === >> "C:\Coding Projects\bo3 mod\build_log.txt" 2>&1
