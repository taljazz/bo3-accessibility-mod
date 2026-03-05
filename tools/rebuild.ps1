Set-Location "C:\Program Files (x86)\Steam\steamapps\common\Call of Duty Black Ops III"
$env:TA_GAME_PATH = "C:\Program Files (x86)\Steam\steamapps\common\Call of Duty Black Ops III\"
$env:TA_TOOLS_PATH = "C:\Program Files (x86)\Steam\steamapps\common\Call of Duty Black Ops III\"
$env:TA_LOCAL_ASSET_CACHE = "C:\Program Files (x86)\Steam\steamapps\common\Call of Duty Black Ops III\share\assetconvert\"

Write-Output "=== GDTDB Update ==="
& ".\gdtdb\gdtdb.exe" /update 2>&1
Write-Output "GDTDB Exit: $LASTEXITCODE"

Write-Output ""
Write-Output "=== Linking zm_mod ==="
& ".\bin\linker_modtools.exe" -language english -fs_game zm_accessibility -modsource zm_mod 2>&1
Write-Output "zm_mod Exit: $LASTEXITCODE"

Write-Output ""
Write-Output "=== Linking core_mod ==="
& ".\bin\linker_modtools.exe" -language english -fs_game zm_accessibility -modsource core_mod 2>&1
Write-Output "core_mod Exit: $LASTEXITCODE"

Write-Output ""
Write-Output "=== Build Complete ==="
