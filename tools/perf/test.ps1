# Runs tools\perf\test.lua: KnoxPerf.lua on the game's own Lua, outside the game -
# once with the counter on (perf=1), once off (perf=0) - and a look at every
# Events.X.Add of Knox's files: one inside a function must have its Remove
# (an Add that runs more than once would pile handlers up for the rest of a game).
$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$game = "C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid"
$java = "C:\Users\pielo\Zomboid\tools\jdk-25\bin\java.exe"
$run = (Join-Path $PSScriptRoot '..\..\java\tools\luacheck\LuaRun.java')
$perf = Join-Path $root "42\media\lua\shared\Knox\KnoxPerf.lua"
Push-Location $game
try {
    foreach ($on in "1", "0") {
        & $java -cp "$game\projectzomboid.jar" $run (Join-Path $PSScriptRoot "stubs.lua") $perf (Join-Path $PSScriptRoot "test.lua") "perf=$on"
    }
} finally { Pop-Location }

# Static: Adds that are indented (inside a function or an if) and name a handler
# must have a Remove of the same name in that file; an anonymous one indented must
# be at file level - the known ones, each looked at (2026-10-24), are listed here.
$fileLevel = @(
    'KnoxMain.lua: Events.OnPreUIDraw.Add(function()',          # inside "if Viewpoint is there" at file level
    'KnoxFootprint.lua: Events.OnTick.Add(function()',          # inside "if not the server" at file level
    'KnoxGenerator.lua: if Events.OnClientCommand then Events.OnClientCommand.Add(G.onClientCommand) end',
    'KnoxGenerator.lua: if Events.OnServerCommand then Events.OnServerCommand.Add(G.onServerCommand) end',
    'KnoxMenuScene.lua: Events.OnClothingUpdated.Add(function(player)', # inside "if Events.OnClothingUpdated" at file level
    'KnoxMenuScene.lua: Events.OnTick.Add(function()',          # the same
    'KnoxMusicNet.lua: if Events.OnClientCommand then Events.OnClientCommand.Add(MN.onClientCommand) end',
    'KnoxMusicNet.lua: if Events.OnServerCommand then Events.OnServerCommand.Add(MN.onServerCommand) end',
    'KnoxMusicNet.lua: Events.OnTick.Add(function()',
    'KnoxMusicNet.lua: if Events.OnGameStart then Events.OnGameStart.Add(function() if MN.client() then startOver() end end) end',
    'KnoxNet.lua: if Events.OnClientCommand then Events.OnClientCommand.Add(N.onClientCommand) end',
    'KnoxNet.lua: if Events.OnServerCommand then Events.OnServerCommand.Add(N.onServerCommand) end',
    'KnoxNet.lua: Events.OnTick.Add(function()',
    'KnoxNet.lua: Events.OnGameStart.Add(function()',
    'KnoxNet.lua: Events.OnCreatePlayer.Add(function(playerNum)'
)
$bad = @(); $inside = 0
foreach ($f in Get-ChildItem -Recurse -Filter *.lua (Join-Path $root "42\media\lua")) {
    if ($f.Name -eq "KnoxPerf.lua") { continue }
    $text = [IO.File]::ReadAllText($f.FullName)
    foreach ($line in [IO.File]::ReadAllLines($f.FullName)) {
        if ($line -notmatch '^\s+\S' -or $line -notmatch '(Events\.\w+|[Tt]ickEvent)\.Add\(') { continue }
        $inside++
        $key = $f.Name + ": " + $line.Trim()
        if ($fileLevel -contains $key) { continue }
        if ($line -match '\.Add\(([\w\.]+)\)') {
            $name = [regex]::Escape($Matches[1])
            if ($text -match "\.Remove\($name\)") { continue }
        }
        $bad += $key
    }
}
if ($bad.Count -eq 0) { "adds inside functions or ifs: $inside, all paired or at file level - pass" }
else { $bad | ForEach-Object { "FAIL add without its Remove: $_" } }
