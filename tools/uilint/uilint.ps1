# Finds text centred by hand in the mod's client Lua (the author, 2026-10-20: every
# new piece needed checking whether its text sat in the middle). Text goes through the
# layout kit of KnoxTheme instead - T.label, T.plate, T.iconButton, T.inkCentre - which
# put it in its band by its pixels.
#
#   tools\uilint\uilint.ps1           report; exit 1 if a file has more than its baseline
#   tools\uilint\uilint.ps1 -update   write the counts of now as the baseline
#
# The baseline (baseline.txt) is what was there when the kit came: old code is moved
# onto the kit bit by bit, and its count only goes down. New code adds none.
param([switch]$update)
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$mod = Split-Path -Parent (Split-Path -Parent $here)
$lua = Join-Path $mod '42\media\lua\client\Knox'
$baseFile = Join-Path $here 'baseline.txt'

# what centring by hand looks like
$rules = @(
    @{ id = 'v-font'; why = 'up and down by the font''s line height (capitals sit high): T.label / T.inkCentre'
       re = '\(\s*[\w\.\[\]]+\s*-\s*(T\.fontH\(|T\.fontTileH|fh\b|ft\b|fontH\b|capH\b|th\b)[^)]*\)?\s*\)\s*/\s*2' },
    @{ id = 'h-measure'; why = 'sideways by the text''s advance width (its side space counts): T.label align centre'
       re = '\(\s*[\w\.\[\]]+\s*-\s*T\.measure\([^)]*\)\s*\)\s*/\s*2' },
    @{ id = 'textCentre'; why = 'T.textCentre / T.drawTextCentre centre by advance width: T.label align centre'
       re = '\bT\.(textCentre|drawTextCentre)\(' }
)

$counts = @{}
$hits = @{}
foreach ($f in Get-ChildItem $lua -Filter *.lua) {
    $n = 0
    $list = @()
    $i = 0
    foreach ($line in [IO.File]::ReadAllLines($f.FullName)) {
        $i++
        if ($line -match '^\s*--') { continue }
        if ($line -match 'uilint: ok') { continue }   # (the kit's own insides, said so on the line)
        foreach ($r in $rules) {
            if ($line -match $r.re) {
                $n++
                $list += ("  {0}:{1}  [{2}] {3}" -f $f.Name, $i, $r.id, $line.Trim())
            }
        }
    }
    if ($n -gt 0) { $counts[$f.Name] = $n; $hits[$f.Name] = $list }
}

if ($update) {
    $out = $counts.Keys | Sort-Object | ForEach-Object { "$_=$($counts[$_])" }
    [IO.File]::WriteAllLines($baseFile, [string[]]$out)
    $total = 0; foreach ($v in $counts.Values) { $total += $v }
    Write-Output "baseline written: $total in $($counts.Count) files"
    exit 0
}

$base = @{}
if (Test-Path $baseFile) {
    foreach ($l in [IO.File]::ReadAllLines($baseFile)) {
        if ($l -match '^(.+)=(\d+)$') { $base[$matches[1]] = [int]$matches[2] }
    }
}
$bad = 0
$total = 0
foreach ($name in ($counts.Keys | Sort-Object)) {
    $total += $counts[$name]
    $was = 0
    if ($base.ContainsKey($name)) { $was = $base[$name] }
    if ($counts[$name] -gt $was) {
        $bad++
        Write-Output ("{0}: {1} centred by hand, baseline {2} - new ones are among:" -f $name, $counts[$name], $was)
        $hits[$name] | ForEach-Object { Write-Output $_ }
    }
}
foreach ($r in $rules) { if ($bad -gt 0) { Write-Output ("[{0}] {1}" -f $r.id, $r.why) } }
$baseTotal = 0; foreach ($v in $base.Values) { $baseTotal += $v }
Write-Output ("centred by hand: {0} (baseline {1}); files over baseline: {2}" -f $total, $baseTotal, $bad)
if ($bad -gt 0) { exit 1 }
