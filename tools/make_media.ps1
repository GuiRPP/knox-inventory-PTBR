# The media library (the author, 2026-11-04: "sort all of KNOX's media so it is easy,
# quick and clear to get at"): MEDIA\ at the mod's root, sections by what a picture is
# for, and "Открыть медиатеку.html" - every picture and video as a thumbnail, a click opens it.
# The files are NOT moved: the scripts in tools\ read them where they are. MEDIA\ holds
# hard links (the same file under a second name: no disk space, an edit shows in both).
# Rebuilt from scratch on each run - run it after new pictures appear.
# Ready work goes to its section; drafts of mockups, old previews and the frames GIFs are
# built from go to "11 Архив" (the author: "everything draft - into the archive").
# Not in git (.gitignore), not in the backup (backup_workspace.ps1 skips MEDIA/).
#
# Usage: powershell -ExecutionPolicy Bypass -File tools\make_media.ps1

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$lib = Join-Path $root "MEDIA"
$mark = Join-Path $lib ".knox_media"   # (only a folder with this mark is ever cleared)
$utf8 = New-Object Text.UTF8Encoding $false
if (-not ('KnoxLink' -as [type])) {
    Add-Type -Name KnoxLink -Namespace '' -MemberDefinition '[DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)] public static extern bool CreateHardLink(string lpFileName, string lpExistingFileName, IntPtr lpSecurityAttributes);'
}

# --- what goes where: the first rule a file's path matches (forward slashes, from the root)
$rules = @(
    @('^tools/art/preview_workshop_winter\.gif$', $null),   # (the same file as preview_workshop.gif)
    @('^tools/art/knox_logo.*_winter\.png$', '01 Логотип\Зима'),
    @('^tools/art/knox_logo[^/]*\.png$', '01 Логотип\Песок'),
    @('^tools/art/preview_workshop\.gif$', '02 Steam\Превью страницы (сейчас)'),
    @('^tools/art/(preview_workshop\.jpg|poster_1024\.png|poster2_322\.png)$', '02 Steam\Постер (неподвижный)'),
    @('^42/poster\.png$', '02 Steam\Значок в списке модов игры'),
    @('^tools/art/gallery_ru_', '02 Steam\Галерея RU'),
    @('^tools/art/gallery_\d', '02 Steam\Галерея EN'),
    @('^tools/art/gif_[a-z]+(_2mb)?\.gif$', '02 Steam\GIF для описания'),
    @('^tools/art/(page|page_v2)/', '02 Steam\Картинки описания'),
    @('^tools/art/roadmap\.png$', '02 Steam\Картинки описания'),
    @('^tools/art/steam_library/', '02 Steam\Библиотека Steam (Project Zomboid)'),
    @('^42/media/knox/news/road/', '03 Новости в игре\Дорожная карта'),
    @('^42/media/knox/news/', '03 Новости в игре\{news}'),
    @('^tools/art/boosty_', '04 Boosty'),
    @('^tools/art/yt_thumb', '05 Соцсети\YouTube'),
    @('^tools/art/avatar_reddit', '05 Соцсети\Reddit'),
    @('^tools/art/dtf', '05 Соцсети\DTF'),
    @('^tools/art/screen_', '06 Скриншоты игры'),
    @('^tools/art/knox_wallpaper', '07 Обои'),
    @('^tools/art/[^/]+\.mp4$', '08 Видео'),
    @('^tools/art/gameicons/', '09 Значки\Значки игры'),
    @('^tools/art/menu_icons_sheet', '09 Значки'),
    @('^\.claude/mockups/radial_icons/', '09 Значки\Радиальное меню'),
    @('^\.claude/mockups/editor/icons/', '09 Значки\Редактор вещей'),
    @('^tools/art/(gear_preview|hands_preview|lens_preview|mock_rig|rig_sheet_ru)', '10 Макеты'),
    @('^\.claude/mockups/(.*/)?(?i:[^/]*final[^/]*)$', '10 Макеты'),   # (final in the file's own name)
    @('^tools/art/(preview_workshop_|poster)', '11 Архив\Старые превью и постеры'),
    @('^tools/art/news_old/', '11 Архив\Старые новости'),
    @('^tools/art/(gif_beta|gif_frames)/', '11 Архив\Кадры для сборки GIF'),
    @('^\.claude/mockups/([^/]+)/', '11 Архив\Черновики макетов\$1'),
    @('^\.claude/mockups/[^/]+$', '11 Архив\Черновики макетов\Разное'),
    @('^tools/art/', '11 Архив\Прочее')
)
$exts = @('.png', '.jpg', '.jpeg', '.gif', '.webp', '.mp4', '.webm')
$videos = @('.mp4', '.webm')

# --- the in-game news: a folder a news entry, "date title (prefix)", from news_ru.txt
$newsName = @{}
$date = ""; $title = ""
foreach ($l in [IO.File]::ReadAllLines((Join-Path $root "42\media\knox\news_ru.txt"), $utf8)) {
    if ($l -match '^# .*\|') {
        $p = $l.Split('|'); $date = $p[1].Trim(); $title = $p[$p.Count - 1].Trim()
        if ($date -match '^(\d\d)\.(\d\d)\.(\d{4})$') { $date = "$($Matches[3])-$($Matches[2])-$($Matches[1])" }
        continue
    }
    if ($l.StartsWith(';')) { continue }
    foreach ($m in [regex]::Matches($l, '\b([a-z]+[0-9]*)_[a-z0-9_]+\.png')) {
        $k = $m.Groups[1].Value
        if (-not $newsName.ContainsKey($k)) {
            $safe = ($title -replace '[\\/:*?"<>|]', ' ' -replace '\s+', ' ').Trim()
            $newsName[$k] = ("$date $safe ($k)").Trim()
        }
    }
}

# --- the files
$found = @()
foreach ($dir in @("tools\art", ".claude\mockups", "42\media\knox\news")) {
    $full = Join-Path $root $dir
    if (-not (Test-Path $full)) { continue }
    $found += Get-ChildItem -LiteralPath $full -Recurse -File | Where-Object { $exts -contains $_.Extension.ToLower() }
}
$found += Get-Item -LiteralPath (Join-Path $root "42\poster.png")

# --- MEDIA cleared (links only: the files themselves stay where they are) and built again
if (Test-Path $lib) {
    if (-not (Test-Path $mark)) { throw "MEDIA exists but is not the library (no .knox_media) - not touched" }
    # (what is inside, not MEDIA itself: an Explorer window open on it holds the folder)
    Get-ChildItem -LiteralPath $lib -Force | Where-Object { $_.Name -ne '.knox_media' } | Remove-Item -Recurse -Force
}
New-Item -ItemType Directory -Force $lib | Out-Null
[IO.File]::WriteAllText($mark, "made by tools\make_media.ps1 - hard links, safe to delete", $utf8)

$placed = @{}   # section -> list of {name, rel}
$taken = @{}
$n = 0
foreach ($f in $found) {
    $rel = $f.FullName.Substring($root.Length + 1).Replace('\', '/')
    $to = $null; $hit = $false
    foreach ($r in $rules) {
        $m = [regex]::Match($rel, $r[0])
        if (-not $m.Success) { continue }
        $hit = $true; $to = $r[1]
        if ($to) {
            if ($m.Groups.Count -gt 1) { $to = $to.Replace('$1', $m.Groups[1].Value) }
            if ($to.Contains('{news}')) {
                $k = ($f.Name -split '_')[0]
                $to = $to.Replace('{news}', $(if ($newsName.ContainsKey($k)) { $newsName[$k] } else { "Прочее" }))
            }
        }
        break
    }
    if (-not $hit -or -not $to) { continue }
    # the mockups' drafts keep their subfolders; elsewhere a flat folder
    $sub = ""
    if ($rel -match '^\.claude/mockups/[^/]+/(.+)/[^/]+$' -and $to.StartsWith('11 ')) { $sub = $Matches[1].Replace('/', '\') }
    $folder = $(if ($sub) { Join-Path $to $sub } else { $to })
    $name = $f.Name
    $key = (Join-Path $folder $name).ToLower()
    for ($i = 2; $taken.ContainsKey($key); $i++) {
        $name = "$($f.BaseName)__$i$($f.Extension)"; $key = (Join-Path $folder $name).ToLower()
    }
    $taken[$key] = $true
    $dest = Join-Path $lib $folder
    if (-not (Test-Path -LiteralPath $dest)) { New-Item -ItemType Directory -Force $dest | Out-Null }
    $link = Join-Path $dest $name
    # (Windows' own CreateHardLink: New-Item -ItemType HardLink reads [ ] as a wildcard, cmd's mklink is slow)
    if (-not [KnoxLink]::CreateHardLink($link, $f.FullName, [IntPtr]::Zero)) { throw "no link for $rel (error $([Runtime.InteropServices.Marshal]::GetLastWin32Error()))" }
    if (-not $placed.ContainsKey($folder)) { $placed[$folder] = New-Object System.Collections.ArrayList }
    [void]$placed[$folder].Add(@{ name = $name; video = ($videos -contains $f.Extension.ToLower()); src = $rel })
    $n++
}

# --- the gallery: a page, every section a block, the archive's folded
function Esc([string]$s) { [Net.WebUtility]::HtmlEncode($s) }
function Href([string]$p) { ($p.Split('\') | ForEach-Object { [Uri]::EscapeDataString($_) }) -join '/' }
$sb = New-Object Text.StringBuilder
[void]$sb.Append(@'
<!doctype html><html lang="ru"><head><meta charset="utf-8"><title>KNOX - медиатека</title>
<style>
body{margin:0;background:#0c0e0e;color:#d9d6c8;font:15px "Segoe UI",sans-serif}
header{position:sticky;top:0;background:#121414;border-bottom:2px solid #2a2e2e;padding:12px 20px;z-index:2}
h1{margin:0 0 6px;font-size:22px;color:#ece8d8;letter-spacing:1px} h1 b{color:#d4c38a}
nav a{color:#d4c38a;margin-right:14px;text-decoration:none;font-size:14px} nav a:hover{color:#ece8d8}
input{background:#0e1010;border:1px solid #2a2e2e;color:#ece8d8;padding:5px 9px;width:260px;margin-top:8px}
main{padding:10px 20px 60px}
details{margin:10px 0;border:1px solid #2a2e2e;background:#121414}
details details{margin:8px 10px;background:#0e1010}
summary{cursor:pointer;padding:9px 12px;font-weight:600;color:#ece8d8}
summary span{color:#8f9289;font-weight:400;margin-left:8px}
.g{display:flex;flex-wrap:wrap;gap:10px;padding:4px 12px 12px}
.t{width:190px;text-decoration:none;color:#8f9289;font-size:12px;word-break:break-all}
.t div{height:140px;display:flex;align-items:center;justify-content:center;background:#090a0a;border:1px solid #242828}
.t:hover div{border-color:#d4c38a} .t:hover{color:#ece8d8}
.t img,.t video{max-width:188px;max-height:138px}
.hide{display:none}
</style></head><body>
<header><h1>KNOX <b>МЕДИАТЕКА</b></h1><nav>
'@)
$tops = $placed.Keys | ForEach-Object { $_.Split('\')[0] } | Sort-Object -Unique
foreach ($t in $tops) { [void]$sb.Append("<a href=`"#$(Href $t)`">$(Esc $t)</a>") }
[void]$sb.Append('</nav><input id="q" placeholder="поиск по имени файла" oninput="f()"></header><main>')
foreach ($t in $tops) {
    $subs = $placed.Keys | Where-Object { $_ -eq $t -or $_.StartsWith("$t\") } | Sort-Object
    $cnt = 0; foreach ($s in $subs) { $cnt += $placed[$s].Count }
    $open = $(if ($t.StartsWith('11 ')) { '' } else { ' open' })
    [void]$sb.Append("<details id=`"$(Href $t)`"$open><summary>$(Esc $t)<span>$cnt</span></summary>")
    foreach ($s in $subs) {
        $inner = $s -ne $t
        if ($inner) {
            $label = $s.Substring($t.Length + 1)
            # (the archive's subfolders folded too: hundreds of pictures)
            [void]$sb.Append("<details$(if ($t.StartsWith('11 ')) { '' } else { ' open' })><summary>$(Esc $label)<span>$($placed[$s].Count)</span></summary>")
        }
        [void]$sb.Append('<div class="g">')
        # (numbers as numbers: gallery_2 before gallery_10)
        foreach ($e in ($placed[$s] | Sort-Object { [regex]::Replace($_.name, '\d+', { $args[0].Value.PadLeft(6, '0') }) })) {
            $h = Href (Join-Path $s $e.name)
            $media = $(if ($e.video) { "<video src=`"$h`" preload=`"metadata`" muted></video>" } else { "<img src=`"$h`" loading=`"lazy`">" })
            [void]$sb.Append("<a class=`"t`" href=`"$h`" title=`"$(Esc $e.src)`"><div>$media</div>$(Esc $e.name)</a>")
        }
        [void]$sb.Append('</div>')
        if ($inner) { [void]$sb.Append('</details>') }
    }
    [void]$sb.Append('</details>')
}
[void]$sb.Append(@'
</main><script>
function f(){const q=document.getElementById('q').value.toLowerCase();
document.querySelectorAll('.t').forEach(a=>a.classList.toggle('hide',q&&!a.textContent.toLowerCase().includes(q)));
if(q)document.querySelectorAll('details').forEach(d=>d.open=!!d.querySelector('.t:not(.hide)'));}
</script></body></html>
'@)
[IO.File]::WriteAllText((Join-Path $lib "Открыть медиатеку.html"), $sb.ToString(), $utf8)
Write-Host "MEDIA: $n files in $($placed.Count) folders"
