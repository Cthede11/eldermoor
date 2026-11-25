# Eldermoor performance presets. Started by "Eldermoor Performance Presets.bat" in the profile folder.
# Changes video settings and mod settings line by line (keybinds and everything else are left alone) and switches
# a few cosmetic, client-only mods off or back on by renaming them to .jar.disabled, which CurseForge shows as
# a disabled mod. What each preset does is listed in presets.json, written by tools/perf.py in the pack's source.
param([string]$Preset = "", [switch]$NoPause)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$spec = [IO.File]::ReadAllText((Join-Path $PSScriptRoot "presets.json")) | ConvertFrom-Json
$utf8 = New-Object System.Text.UTF8Encoding($false)

function Done([int]$code) {
    if (-not $NoPause) { Write-Host ""; Read-Host "Press Enter to close" | Out-Null }
    exit $code
}

function Get-Hardware {
    $hw = @{ RamGb = 0; Cores = 0; Cpu = "?"; Gpus = @() }
    try {
        $hw.RamGb = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB)
        $cpu = @(Get-CimInstance Win32_Processor)[0]
        $hw.Cpu = $cpu.Name.Trim(); $hw.Cores = [int]$cpu.NumberOfCores
        $hw.Gpus = @(Get-CimInstance Win32_VideoController | ForEach-Object { $_.Name })
    } catch {}
    return $hw
}

# 0 = no real graphics card, 1 = old or small card, 2 = mid, 3 = strong
function Get-GpuClass($names) {
    $best = 0
    foreach ($n in $names) {
        $c = 0
        if ($n -match 'RTX\s*(\d)0(\d)0') {
            $gen = [int]$Matches[1]; $tier = [int]$Matches[2]
            if ($gen -ge 3 -and $tier -ge 6) { $c = 3 } elseif ($gen -ge 3 -or $tier -ge 6) { $c = 2 } else { $c = 1 }
        }
        elseif ($n -match 'GTX\s*(\d{3,4})') {
            $m = [int]$Matches[1]
            if ($m -in 1070, 1080, 1660) { $c = 2 } elseif ($m -ge 950) { $c = 1 } else { $c = 0 }
        }
        elseif ($n -match 'RX\s*(\d)(\d)\d\d') {
            $gen = [int]$Matches[1]; $tier = [int]$Matches[2]
            if ($gen -ge 6 -and $tier -ge 7) { $c = 3 } elseif ($gen -ge 6 -and $tier -ge 6) { $c = 2 } elseif ($gen -ge 5) { $c = 2 } else { $c = 1 }
        }
        elseif ($n -match 'RX\s*(\d{3})\b') { $c = 1 }
        elseif ($n -match 'Arc.*\b[AB]\d{3}') { $c = 2 }
        if ($c -gt $best) { $best = $c }
    }
    return $best
}

function Get-Recommendation($hw) {
    $g = Get-GpuClass $hw.Gpus
    if ($hw.RamGb -gt 0 -and $hw.RamGb -lt 12) { return "potato" }
    if ($g -eq 0) { return "potato" }
    if ($g -eq 1 -or $hw.RamGb -lt 15 -or $hw.Cores -lt 6) { return "low" }
    if ($g -eq 3 -and $hw.RamGb -ge 24) { return "high" }
    return "balanced"
}

# Java memory to set in CurseForge: the preset's figure, but never more than the PC can spare
function Get-Memory($p, $hw) {
    $want = [int]$p.memory_mb
    if ($hw.RamGb -gt 0) {
        $cap = [int](($hw.RamGb * 1024) * 0.55)
        if ($hw.RamGb -ge 15) { $cap = [int](($hw.RamGb - 7) * 1024) }
        if ($want -gt $cap) { $want = $cap }
    }
    if ($want -lt 4096) { $want = 4096 }
    return [int]([math]::Floor($want / 512) * 512)
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

function Apply-Edits($edits) {
    $changed = 0
    foreach ($group in ($edits | Group-Object file)) {
        $path = Join-Path $root ($group.Name -replace '/', '\')
        if (-not (Test-Path -LiteralPath $path)) { continue }
        $text = [IO.File]::ReadAllText($path)
        $old = $text
        foreach ($e in $group.Group) {
            $start = 0
            if ($e.after) {
                $m = [regex]::Match($text, $e.after)
                if (-not $m.Success) { continue }
                $start = $m.Index + $m.Length
            }
            $m = ([regex]$e.find).Match($text, $start)
            if (-not $m.Success) {
                if ($e.add) {
                    if ($text.Length -gt 0 -and -not $text.EndsWith("`n")) { $text += "`n" }
                    $text += $e.line + "`n"
                }
                continue
            }
            $found = $m.Value.TrimEnd("`r")
            $indent = $found.Substring(0, $found.Length - $found.TrimStart(" ", "`t").Length)
            $line = $indent + $e.line
            if ($found.TrimEnd().EndsWith(",") -and -not $line.EndsWith(",")) { $line += "," }
            $text = $text.Substring(0, $m.Index) + $line + $text.Substring($m.Index + $found.Length)
        }
        if ($text -ne $old) { [IO.File]::WriteAllText($path, $text, $utf8); $changed++ }
    }
    return $changed
}

function Starts-WithAny($name, $prefixes) {
    foreach ($p in $prefixes) { if ($name.StartsWith($p, [System.StringComparison]::OrdinalIgnoreCase)) { return $true } }
    return $false
}

function Apply-Mods($disable) {
    $mods = Join-Path $root "mods"
    $off = @(); $on = @()
    if (-not (Test-Path -LiteralPath $mods)) { return @{ Off = $off; On = $on } }
    foreach ($f in Get-ChildItem -LiteralPath $mods -File) {
        if ($f.Name.EndsWith(".jar") -and (Starts-WithAny $f.Name $disable)) {
            $target = Join-Path $mods ($f.Name + ".disabled")
            if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Force }
            Rename-Item -LiteralPath $f.FullName -NewName ($f.Name + ".disabled"); $off += $f.Name
        }
        elseif ($f.Name.EndsWith(".jar.disabled") -and (Starts-WithAny $f.Name $spec.managed) -and -not (Starts-WithAny $f.Name $disable)) {
            $name = $f.Name.Substring(0, $f.Name.Length - ".disabled".Length)
            if (Test-Path -LiteralPath (Join-Path $mods $name)) { Remove-Item -LiteralPath $f.FullName -Force }
            else { Rename-Item -LiteralPath $f.FullName -NewName $name; $on += $name }
        }
    }
    return @{ Off = $off; On = $on }
}

function Apply-ResourcePacks($packs) {
    if ($null -eq $packs) { return $false }
    $path = Join-Path $root "config\resourcepackoverrides.json"
    if (-not (Test-Path -LiteralPath $path)) { return $false }
    $data = [IO.File]::ReadAllText($path) | ConvertFrom-Json
    $data.default_packs = @($packs)
    $data.pack_overrides.'1' = @($packs)
    [IO.File]::WriteAllText($path, ($data | ConvertTo-Json -Depth 10), $utf8)
    return $true
}

Write-Host ""
Write-Host "  Eldermoor performance presets" -ForegroundColor Yellow
Write-Host "  -----------------------------"
if (Test-GameRunning) {
    Write-Host "  The game is running from this profile. Close it first, then run this again." -ForegroundColor Red
    Done 1
}
$hw = Get-Hardware
$rec = Get-Recommendation $hw
$current = ""
$curFile = Join-Path $PSScriptRoot "current.txt"
if (Test-Path -LiteralPath $curFile) { $current = ([IO.File]::ReadAllText($curFile)).Trim() }

if (-not $Preset) {
    Write-Host ("  This PC: {0} GB RAM, {1} ({2} cores)" -f $hw.RamGb, $hw.Cpu, $hw.Cores)
    foreach ($g in $hw.Gpus) { Write-Host "           $g" }
    Write-Host ""
    $i = 1
    foreach ($k in $spec.order) {
        $p = $spec.presets.$k
        $tag = ""
        if ($k -eq $rec) { $tag += "  <- suggested for this PC" }
        if ($k -eq $current) { $tag += "  (in use now)" }
        Write-Host ("  {0}. {1}{2}" -f $i, $p.title, $tag) -ForegroundColor Cyan
        Write-Host ("     {0}" -f $p.for)
        Write-Host ("     {0}" -f $p.what)
        $i++
    }
    Write-Host ""
    $answer = (Read-Host "  Type 1-$($spec.order.Count) and press Enter (just Enter = suggested, Q = cancel)").Trim().ToLower()
    if ($answer -eq "q") { exit 0 }
    if ($answer -eq "") { $Preset = $rec }
    elseif ($answer -match '^\d+$' -and [int]$answer -ge 1 -and [int]$answer -le $spec.order.Count) { $Preset = $spec.order[[int]$answer - 1] }
    else { $Preset = $answer }
}
if ($Preset -eq "auto") { $Preset = $rec }
if (-not ($spec.order -contains $Preset)) {
    Write-Host "  Unknown preset '$Preset'. Choose one of: $($spec.order -join ', '), auto" -ForegroundColor Red
    Done 1
}

$p = $spec.presets.$Preset
$n = Apply-Edits $p.edits
$leanPacks = Apply-ResourcePacks $p.resource_packs
$mods = Apply-Mods @($p.disable)
[IO.File]::WriteAllText($curFile, $Preset + "`n", $utf8)

Write-Host ""
Write-Host ("  {0} preset applied: {1} settings files changed." -f $p.title, $n) -ForegroundColor Green
if ($leanPacks) {
    if (@($p.resource_packs) -contains "file/JICKLUS.zip") { Write-Host "    texture packs: the pack's full set" }
    else { Write-Host "    texture packs: the lean set (vanilla-style textures)" }
}
foreach ($f in $mods.Off) {
    $label = $f
    foreach ($k in $spec.labels.PSObject.Properties) { if ($f.StartsWith($k.Name)) { $label = $k.Value } }
    Write-Host "    switched off: $label"
}
foreach ($f in $mods.On) { Write-Host "    switched back on: $f" }
Write-Host ""
Write-Host ("  One more step, in the CurseForge app: right-click the profile > Profile Options,") -ForegroundColor Yellow
Write-Host ("  untick 'Use system memory settings' and set Allocated Memory to {0} MB." -f (Get-Memory $p $hw)) -ForegroundColor Yellow
if ($p.jvm_args) {
    Write-Host ""
    Write-Host "  For this preset, also replace the Java arguments: CurseForge > Settings > Minecraft >" -ForegroundColor Yellow
    Write-Host "  Java Settings > Additional Arguments (garbage collector settings tuned for this preset's memory):" -ForegroundColor Yellow
    Write-Host ("    {0}" -f $p.jvm_args)
    try { Set-Clipboard -Value $p.jvm_args; Write-Host "  (copied to the clipboard: paste with Ctrl+V)" } catch {}
}
Write-Host "  Every setting can still be changed in the game's Video Settings afterwards."
Done 0
