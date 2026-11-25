# Eldermoor updater. Started by "Update Eldermoor.bat" in the profile folder, with the game closed.
#
# Brings this profile up to the newest Eldermoor release on GitHub, downloading only what changed:
#   - a file the pack changed is replaced (the old copy is kept in eldermoor-update\backup\<time>\ if you had edited it);
#   - a file you changed yourself, which the pack did not change, is left alone (settings, keybinds, configs);
#   - a file the pack no longer has is removed (backed up first); files the pack never had are never touched;
#   - your worlds, screenshots, servers list, video settings and any mods you added yourself stay as they are;
#   - a mod the performance preset switched off (.jar.disabled) stays off, and the preset is applied again at the end.
# Where the pack lives is in eldermoor-update\source.json. The pack's source is tools/release.py.
param([switch]$NoPause, [switch]$Check)
$ErrorActionPreference = "Stop"
$here = $PSScriptRoot
$root = Split-Path -Parent $here
$utf8 = New-Object System.Text.UTF8Encoding($false)
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

function Done([int]$code) {
    if (-not $NoPause) { Write-Host ""; Read-Host "Press Enter to close" | Out-Null }
    exit $code
}

function Test-GameRunning {
    try {
        $needle = $root.TrimEnd('\').ToLower()
        foreach ($p in Get-CimInstance Win32_Process -Filter "Name like 'java%'") {
            if ($p.CommandLine -and $p.CommandLine.ToLower().Contains($needle)) { return $true }
        }
    } catch {}
    return $false
}

function Get-Sha1([string]$path) {
    return (Get-FileHash -LiteralPath $path -Algorithm SHA1).Hash.ToLower()
}

function Local-Path([string]$rel) {
    return Join-Path $root ($rel -replace '/', '\')
}

function Escape-Path([string]$rel) {
    return (($rel -split '/') | ForEach-Object { [Uri]::EscapeDataString($_) }) -join '/'
}

$web = New-Object Net.WebClient
$web.Headers.Add("User-Agent", "Eldermoor-updater")

function Fetch([string]$url, [string]$dest) {
    $dir = Split-Path -Parent $dest
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    for ($try = 1; $try -le 3; $try++) {
        try { $web.DownloadFile($url, $dest); return } catch {
            if ($try -eq 3) { throw "could not download $url ($($_.Exception.Message))" }
            Start-Sleep -Seconds (2 * $try)
        }
    }
}

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupDir = Join-Path $here ("backup\" + $stamp)
function Backup([string]$rel, [string]$local) {
    $dest = Join-Path $backupDir ($rel -replace '/', '\')
    $dir = Split-Path -Parent $dest
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    Copy-Item -LiteralPath $local -Destination $dest -Force
}

Write-Host ""
Write-Host "  Eldermoor updater" -ForegroundColor Cyan
if (Test-GameRunning) {
    Write-Host "  Minecraft is running from this profile. Close the game, then run the updater again." -ForegroundColor Red
    Done 1
}

# ---- where the pack is, and what this profile has
$source = [IO.File]::ReadAllText((Join-Path $here "source.json")) | ConvertFrom-Json
$stateFile = Join-Path $here "installed.json"
$installed = @{}
$installedVersion = ""
if (Test-Path -LiteralPath $stateFile) {
    $state = [IO.File]::ReadAllText($stateFile) | ConvertFrom-Json
    $installedVersion = $state.version
    foreach ($p in $state.files.PSObject.Properties) { $installed[$p.Name] = $p.Value }
}

$tmpManifest = Join-Path $here "manifest.download"
try { Fetch $source.manifest $tmpManifest } catch {
    Write-Host "  Could not reach the Eldermoor release: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "  Check your internet connection and try again."
    Done 1
}
$manifest = [IO.File]::ReadAllText($tmpManifest) | ConvertFrom-Json
Remove-Item -LiteralPath $tmpManifest -Force

$was = if ($installedVersion) { $installedVersion } else { "not set up by the updater yet" }
Write-Host ("  This profile: {0}    Newest: {1}" -f $was, $manifest.version)

# Forge is set by CurseForge, not by files: say so when it must change
$inst = Join-Path $root "minecraftinstance.json"
if (Test-Path -LiteralPath $inst) {
    try {
        $loader = ([IO.File]::ReadAllText($inst) | ConvertFrom-Json).baseModLoader.name
        if ($loader -and $loader -ne ("forge-" + $manifest.forge)) {
            Write-Host ""
            Write-Host ("  This release needs Forge {0}, the profile has {1}." -f $manifest.forge, $loader) -ForegroundColor Yellow
            Write-Host "  In CurseForge: right-click the profile > Profile Options > Modloader > Forge $($manifest.forge)."
        }
    } catch {}
}

# ---- work out what to do
$keep = @{}
foreach ($k in $manifest.keep) { $keep[$k] = $true }
$wanted = @{}
$todo = New-Object System.Collections.ArrayList
$kept = 0
foreach ($f in $manifest.files) {
    $wanted[$f.path] = $true
    $local = Local-Path $f.path
    if (-not (Test-Path -LiteralPath $local) -and $f.path.EndsWith(".jar") -and (Test-Path -LiteralPath ($local + ".disabled"))) {
        $local = $local + ".disabled"   # switched off by the performance preset: keep it off
    }
    $have = $null
    if (Test-Path -LiteralPath $local) { $have = Get-Sha1 $local }
    $last = $installed[$f.path]
    if ($have -eq $f.sha1) { $installed[$f.path] = $f.sha1; continue }
    if ($have -and $keep.ContainsKey($f.path)) { $kept++; continue }           # installed once, then it is yours
    if ($have -and $last -and $last -eq $f.sha1) { $kept++; continue }      # you changed it; the pack did not
    [void]$todo.Add(@{ f = $f; local = $local; edited = [bool]($have -and $last -ne $have) })
}
$remove = New-Object System.Collections.ArrayList
foreach ($rel in @($installed.Keys)) {
    if (-not $wanted.ContainsKey($rel)) {
        foreach ($cand in @((Local-Path $rel), ((Local-Path $rel) + ".disabled"))) {
            if (Test-Path -LiteralPath $cand) { [void]$remove.Add(@{ rel = $rel; local = $cand }) }
        }
        $installed.Remove($rel)
    }
}
# mods that left the pack in releases before this updater existed (old versions, removed mods)
$modsDir = Join-Path $root "mods"
if (Test-Path -LiteralPath $modsDir) {
    foreach ($jar in Get-ChildItem -LiteralPath $modsDir -File) {
        $name = $jar.Name -replace '\.disabled$', ''
        if ($wanted.ContainsKey("mods/" + $name)) { continue }
        $retired = $false
        foreach ($r in $manifest.retired) { if ($name -eq $r -or ($r.EndsWith("*") -and $name.StartsWith($r.TrimEnd("*")))) { $retired = $true } }
        if ($retired -and -not ($remove | Where-Object { $_.local -eq $jar.FullName })) {
            [void]$remove.Add(@{ rel = "mods/" + $jar.Name; local = $jar.FullName })
        }
    }
}

# files the pack may not re-host (the Complementary shader pack's license allows it in modpacks only through Modrinth
# or CurseForge): fetched from their official download when missing; a file already there is never replaced or removed
$ext = New-Object System.Collections.ArrayList
foreach ($x in @($manifest.external)) {
    if ($x -and -not (Test-Path -LiteralPath (Local-Path $x.path))) { [void]$ext.Add($x) }
}
$bytes = 0
foreach ($t in $todo) { $bytes += [int64]$t.f.size }
foreach ($x in $ext) { $bytes += [int64]$x.size }
Write-Host ("  To download: {0} file(s), {1:N1} MB.  To remove: {2}.  Your own changes kept: {3}." -f ($todo.Count + $ext.Count), ($bytes / 1MB), $remove.Count, $kept)
if ($Check) { Done 0 }
if ($todo.Count -eq 0 -and $ext.Count -eq 0 -and $remove.Count -eq 0 -and $installedVersion -eq $manifest.version) {
    Write-Host "  Already up to date." -ForegroundColor Green
    Done 0
}

# ---- download, check, put in place
$i = 0
foreach ($t in $todo) {
    $i++
    $f = $t.f
    $url = if ($f.asset) { $manifest.assets_base + $f.asset } else { $manifest.files_base + (Escape-Path $f.path) }
    Write-Host ("  [{0}/{1}] {2} ({3:N1} MB)" -f $i, $todo.Count, $f.path, ($f.size / 1MB))
    $tmp = $t.local + ".eldermoor-download"
    Fetch $url $tmp
    $got = Get-Sha1 $tmp
    if ($got -ne $f.sha1) {
        Remove-Item -LiteralPath $tmp -Force
        Write-Host "  $($f.path) arrived damaged (checksum differs). Nothing else was changed for it; run the updater again." -ForegroundColor Red
        continue
    }
    if (Test-Path -LiteralPath $t.local) {
        if ($t.edited) { Backup $f.path $t.local }
        Remove-Item -LiteralPath $t.local -Force
    }
    Move-Item -LiteralPath $tmp -Destination $t.local
    $installed[$f.path] = $f.sha1
}
foreach ($x in $ext) {
    $local = Local-Path $x.path
    Write-Host ("  {0} ({1:N1} MB, from {2})" -f $x.path, ($x.size / 1MB), ([Uri]$x.url).Host)
    $tmp = $local + ".eldermoor-download"
    try { Fetch $x.url $tmp } catch { Write-Host "  could not download $($x.path); the game works without it, run the updater again later." -ForegroundColor Yellow; continue }
    if ((Get-Sha1 $tmp) -ne $x.sha1) { Remove-Item -LiteralPath $tmp -Force; Write-Host "  $($x.path) arrived damaged; run the updater again." -ForegroundColor Red; continue }
    Move-Item -LiteralPath $tmp -Destination $local
}
foreach ($r in $remove) {
    Backup $r.rel $r.local
    Remove-Item -LiteralPath $r.local -Force
    Write-Host "  removed $($r.rel) (no longer in the pack; a copy is in eldermoor-update\backup)"
}

# ---- remember what is installed
$files = [ordered]@{}
foreach ($k in ($installed.Keys | Sort-Object)) { $files[$k] = $installed[$k] }
$out = [ordered]@{ version = $manifest.version; updated = (Get-Date -Format "yyyy-MM-dd HH:mm"); files = $files }
[IO.File]::WriteAllText($stateFile, ($out | ConvertTo-Json -Depth 4), $utf8)

# ---- the performance preset in use goes back on (a changed settings file may have reset part of it)
$cur = Join-Path $root "eldermoor-presets\current.txt"
$apply = Join-Path $root "eldermoor-presets\apply.ps1"
if ($todo.Count -gt 0 -and (Test-Path -LiteralPath $cur) -and (Test-Path -LiteralPath $apply)) {
    $preset = ([IO.File]::ReadAllText($cur)).Trim()
    if ($preset) {
        Write-Host ""
        Write-Host "  Applying your performance preset ($preset) again..."
        & powershell -NoProfile -ExecutionPolicy Bypass -File $apply -Preset $preset -NoPause | Out-Host
    }
}

Write-Host ""
Write-Host ("  Eldermoor is now {0}." -f $manifest.version) -ForegroundColor Green
if ($remove.Count -gt 0 -or ($todo | Where-Object { $_.edited })) {
    Write-Host "  Files you had changed that the pack replaced are in: $backupDir"
}
Done 0
