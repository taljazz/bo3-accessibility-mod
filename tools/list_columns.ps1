$header = (Get-Content "C:\Program Files (x86)\Steam\steamapps\common\Call of Duty Black Ops III\share\raw\sound\aliases\zm_mod.csv" -TotalCount 1)
$cols = $header.Split(',')
for ($i = 0; $i -lt $cols.Length; $i++) {
    Write-Output "$i`: $($cols[$i])"
}
