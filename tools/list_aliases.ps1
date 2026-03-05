$lines = Get-Content "C:\Program Files (x86)\Steam\steamapps\common\Call of Duty Black Ops III\share\raw\sound\aliases\zm_mod.csv" | Select-Object -Skip 1
foreach ($line in $lines) {
    if ($line.Trim() -ne "") {
        $name = $line.Split(',')[0]
        Write-Output $name
    }
}
