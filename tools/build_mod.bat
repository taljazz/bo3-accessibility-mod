@echo off
set "TA_GAME_PATH=C:\Program Files (x86)\Steam\steamapps\common\Call of Duty Black Ops III\"
set "TA_TOOLS_PATH=C:\Program Files (x86)\Steam\steamapps\common\Call of Duty Black Ops III\"
set "TA_LOCAL_ASSET_CACHE=C:\Program Files (x86)\Steam\steamapps\common\Call of Duty Black Ops III\share\assetconvert\"

echo === Updating GDT Database ===
"%TA_TOOLS_PATH%gdtdb\gdtdb.exe" /update
echo GDTDB Exit Code: %ERRORLEVEL%

echo.
echo === Linking core_mod zone ===
"%TA_TOOLS_PATH%bin\linker_modtools.exe" -language english -fs_game zm_accessibility -modsource core_mod
echo core_mod Link Exit Code: %ERRORLEVEL%

echo.
echo === Linking zm_mod zone ===
"%TA_TOOLS_PATH%bin\linker_modtools.exe" -language english -fs_game zm_accessibility -modsource zm_mod
echo zm_mod Link Exit Code: %ERRORLEVEL%

echo.
echo === Build complete ===
