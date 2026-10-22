# Reads every item of the game's scripts (media\scripts, recursively) into tools\material\items.tsv:
# one line per item with the fields KnoxMaterial.lua decides a thing's material by. In the game the
# same fields come from item:getScriptItem() (KnoxMaterial.infoOf); here from the text.
param([string]$Scripts = 'C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid\media\scripts')
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$fields = 'ItemType','DisplayCategory','Weight','Tags','FabricType','WorldStaticModel','StaticModel',
          'DropSound','PlaceOneSound','FillFromTapSound','BodyLocation','FoodType','CannedFood','Packaged',
          'EatType','Icon','ClothingItem','DisplayName'
$rows = New-Object System.Collections.Generic.List[string]
$rows.Add((@('fullType') + $fields + @('fluid') -join "`t"))
$count = 0
foreach ($f in Get-ChildItem $Scripts -Recurse -Filter *.txt) {
    $text = [IO.File]::ReadAllText($f.FullName)
    $text = [regex]::Replace($text, '/\*.*?\*/', '', 'Singleline')   # block comments
    $module = 'Base'
    $lines = $text -split "`r?`n"
    $i = 0
    while ($i -lt $lines.Count) {
        $line = $lines[$i].Trim()
        if ($line -match '^module\s+(\w+)') { $module = $Matches[1] }
        if ($line -match '^item\s+([\w\-\.]+)\s*(\{)?\s*$') {
            $name = $Matches[1]
            $rec = @{}
            $fluid = ''
            $depth = 0
            $opened = $false
            # (the brace may be on the item's line or the next)
            for ($j = $i; $j -lt $lines.Count; $j++) {
                $l = $lines[$j].Trim()
                $opens = ([regex]::Matches($l, '\{')).Count
                $closes = ([regex]::Matches($l, '\}')).Count
                if ($depth -ge 2 -and $l -match '^component\s+FluidContainer') { $fluid = '1' }
                if ($l -match '^component\s+FluidContainer') { $fluid = '1' }
                if ($depth -eq 1 -and $l -match '^([A-Za-z]\w*)\s*=\s*(.*?)\s*,?\s*$') {
                    $rec[$Matches[1].ToLower()] = $Matches[2]
                }
                $depth += $opens - $closes
                if ($opens -gt 0) { $opened = $true }
                if ($opened -and $depth -le 0) { break }
            }
            $vals = foreach ($k in $fields) { $v = $rec[$k.ToLower()]; if ($v) { ($v -replace "[`t`r`n]", ' ') } else { '' } }
            $rows.Add((@("$module.$name") + $vals + @($fluid) -join "`t"))
            $count++
            $i = $j
        }
        $i++
    }
}
[IO.File]::WriteAllLines((Join-Path $here 'items.tsv'), $rows, (New-Object Text.UTF8Encoding $false))
"items: $count -> tools\material\items.tsv"
