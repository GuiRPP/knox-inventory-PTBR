# How loud the game's sound events Knox uses are, to level them (KnoxSoundLevel.lua).
# The game's events can't be measured while it runs, so their recordings are: each event's
# FMOD path (the game's scripts: sound X { clip { event = A/B/C } }) is matched to the
# recordings of ZomboidSound.bank by name (".../KeyRing/StoreItem" -> player_key_ring_store_item_01..),
# those are decoded with vgmstream and measured (Loudness.java: K-weighted, the loudest 0.4 s).
# Out: tools\sound\levels.txt - event, recordings found, mean dB, spread (max - min).
param([string[]]$Events)
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$game = 'C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid'
$java = 'C:\Users\pielo\Zomboid\tools\jdk-25\bin\java.exe'
$cli = 'C:\Users\pielo\Zomboid\tools\vgmstream\bin\vgmstream-cli.exe'
$work = 'C:\Users\pielo\Zomboid\tools\vgmstream\work'
$bank = Join-Path $game 'media\sound\banks\Desktop\ZomboidSound.bank'
$tools = (Join-Path $PSScriptRoot '..\..\java\tools\soundlevel')
New-Item -ItemType Directory -Force "$work\wav" | Out-Null

if (-not (Test-Path "$work\names.txt")) { & $java "$tools\BankNames.java" $bank "$work\names.txt" | Out-Null }
$names = @{}
foreach ($l in Get-Content "$work\names.txt") { $p = $l -split "`t"; $names[[int]$p[0]] = $p[1].Trim() }

# event name -> FMOD path
$paths = @{}
foreach ($f in Get-ChildItem (Join-Path $game 'media\scripts') -Recurse -Filter *.txt) {
    $t = [IO.File]::ReadAllText($f.FullName)
    foreach ($m in [regex]::Matches($t, 'sound\s+(\w+)\s*\{(.*?)\n\s*\}', 'Singleline')) {
        $e = [regex]::Match($m.Groups[2].Value, 'event\s*=\s*([^,\s]+)')
        if ($e.Success -and -not $paths.ContainsKey($m.Groups[1].Value)) { $paths[$m.Groups[1].Value] = $e.Groups[1].Value }
    }
}
function snake($s) { (($s -creplace '([a-z0-9])([A-Z])', '$1_$2') -creplace '([A-Z])([A-Z][a-z])', '$1_$2').ToLower() }

# (where the path's words don't lead to the right recordings: read by eye in names.txt)
$exact = @{
    CloseBook = '^player_reading_book_close_\d+$'
    WaterDispenserAddBottle = '^object_water_dispenser_bottle_place_\d+$'
    StoreItemParcelSmall = '^player_box_small_store_item_\d+$'
    StoreItemParcelMedium = '^player_box_store_item_\d+$'
    StoreItemParcelLarge = '^player_box_large_store_item_\d+$'
    UIObjectMenuObjectPickup = '^ui_object_menu_pickup_?\d*$'
    UIObjectMenuObjectPlace = '^ui_object_menu_place_?\d*$'
    UIObjectMenuObjectRotate = '^object_rotate_object\d+$'
    RummageInInventory = '^player_rummage_in_inventory_loop_\d+$'
    ForagingPickup = '^player_foley_foraging_item_pickup_\d+$'
}

# (a container whose recordings are named after another: Containers/<key>/Open -> player_<value>_open_NN;
# the ones marked * are guesses by what the thing is, not read from the bank)
$alias = @{
    ProtectiveCaseSmall = 'small_protective_case'; ProtectiveCaseMedium = 'medium_protective_case'; ProtectiveCaseLarge = 'large_protective_case'
    InstrumentCaseSmall = 'small_instrument_case'; InstrumentCaseLarge = 'large_instrument_case'
    ToolRollFabric = 'toolroll_fabric'; ToolRollLeather = 'toolroll_leather'; ShoulderHolster = 'holster'
    ParcelSmall = 'box_small'; ParcelMedium = 'box'; ParcelLarge = 'box_large'
    PresentSmall = 'box_small'; PresentMedium = 'box'; PresentLarge = 'box_large'                     # *
    ProduceBoxSmall = 'box_small'; ProduceBoxMedium = 'box'; ProduceBoxLarge = 'box_large'            # *
    HatBox = 'box'; ShoeBox = 'box_small'                                                            # *
    Satchel = 'bag'; SatchelFishing = 'bag'; SatchelMail = 'bag'; SatchelMedical = 'bag'; SatchelMilitary = 'bag'   # *
    SheetSlingBag = 'bag'; ToteBag = 'bag'; HydrationPack = 'bag'; HideFannyPack = 'bag'; ClothGunCase = 'bag'     # *
    Suitcase = 'large_protective_case'; BulkyProtectiveContainer = 'large_protective_case'                         # *
    BiohazardContainer = 'medium_protective_case'; Cooler = 'large_protective_case'; AmmunitionBox = 'small_metal_box'  # *
    FirstAidKitCamping = 'medium_plastic_box'; FirstAidKitMilitary = 'medium_protective_case'                      # *
    MakeupCase = 'small_protective_case'; Humidor = 'small_wooden_box'; PhotoAlbum = 'reading_book'                # *
    HalloweenBucket = 'medium_plastic_box'; CookieJarTeddy = 'cookie_jar'                                          # *
}

$rows = @("# event`trecordings`tdB`tspread`tnames")
foreach ($ev in $Events) {
    $path = $paths[$ev]
    if (-not $path) { $rows += "$ev`t0`t`t`t(no event in the scripts)"; continue }
    $seg = $path -split '/'
    $hits = @()
    if ($exact.ContainsKey($ev)) {
        $hits = @($names.GetEnumerator() | ? { $_.Value -match $exact[$ev] } | Sort-Object Value)
    } elseif ($seg.Count -ge 2 -and $alias.ContainsKey($seg[-2])) {
        $rx = '^player_' + $alias[$seg[-2]] + '_' + (snake $seg[-1]) + '_\d+$'
        $hits = @($names.GetEnumerator() | ? { $_.Value -match $rx } | Sort-Object Value)
    } else {
        $keys = @()
        if ($seg.Count -ge 2) { $keys += (snake $seg[-2]) + '_' + (snake $seg[-1]) }
        foreach ($k in $keys) {
            $rx = '^(player|object|ui|item|firearm|world)_(\w+_)?' + [regex]::Escape($k) + '_?\d*$'
            $hits = @($names.GetEnumerator() | ? { $_.Value -match $rx } | Sort-Object Value)
            if ($hits.Count -gt 0) { break }
        }
    }
    if ($hits.Count -eq 0) { $rows += "$ev`t0`t`t`t($path)"; continue }
    $dbs = @()
    foreach ($h in $hits | Select-Object -First 8) {
        $wav = "$work\wav\$($h.Value).wav"
        if (-not (Test-Path $wav)) { & $cli -s $h.Key -o $wav $bank | Out-Null }
        $out = & $java "$tools\Loudness.java" $wav
        $db = [double](($out -split "`t")[1])
        $dbs += $db
    }
    # (the mean of powers, not of dB: a loud take weighs as loud as it is)
    $pw = ($dbs | % { [math]::Pow(10, $_ / 10) } | Measure-Object -Average).Average
    $mean = 10 * [math]::Log10($pw)
    $spread = ($dbs | Measure-Object -Maximum).Maximum - ($dbs | Measure-Object -Minimum).Minimum
    $rows += ("{0}`t{1}`t{2:F1}`t{3:F1}`t{4}" -f $ev, $hits.Count, $mean, $spread, (($dbs | % { '{0:F1}' -f $_ }) -join ' '))
}
[IO.File]::WriteAllLines((Join-Path $here 'levels.txt'), $rows, (New-Object Text.UTF8Encoding $false))

# the mod's table: the volume that brings each measured event to one level, TARGET dB
# (a factor, 0.2..4: FMOD takes volumes over 1). Events not measured are left out (1).
$TARGET = -36.0
$lua = @(
    '-- Generated by tools\sound\levels.ps1 - do not edit by hand (rerun it).',
    '-- The volume each of the game''s sound events Knox plays needs to sound as loud as the',
    "-- others: its recordings in ZomboidSound.bank measured (K-weighted, the loudest 0.4 s), brought to $TARGET dB.",
    'KnoxSoundLevel = {'
)
foreach ($r in $rows | Select -Skip 1) {
    $p = $r -split "`t"
    if ($p[1] -eq '0' -or -not $p[2]) { continue }
    $db = [double]::Parse($p[2].Replace(',', '.'), [Globalization.CultureInfo]::InvariantCulture)
    $g = [math]::Min(4.0, [math]::Max(0.2, [math]::Pow(10, ($TARGET - $db) / 20)))
    $inv = [Globalization.CultureInfo]::InvariantCulture
    $lua += ('    {0} = {1},   -- {2} dB' -f $p[0], $g.ToString('0.000', $inv), $db.ToString('0.0', $inv))
}
$lua += '}'
$lua += 'return KnoxSoundLevel'
$mod = Split-Path -Parent (Split-Path -Parent $here)
[IO.File]::WriteAllLines((Join-Path $mod '42\media\lua\shared\Knox\KnoxSoundLevelData.lua'), $lua, (New-Object Text.UTF8Encoding $false))
$rows
