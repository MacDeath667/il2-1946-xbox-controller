param([string]$GamePath, [string]$Profile, [switch]$NoShortcut)
$ErrorActionPreference = 'Stop'
# IL-2 INI files use escaped names / legacy ANSI text, not UTF-8.
$encoding = [Text.Encoding]::GetEncoding(1251)
function Set-IniValue([string]$Text, [string]$Section, [string]$Key, [string]$Value) {
    $lines = [Collections.Generic.List[string]]::new()
    foreach ($line in ($Text -split '\r\n|\n|\r')) { $lines.Add($line) }
    $sectionStart = -1; $sectionEnd = $lines.Count
    for ($i=0; $i -lt $lines.Count; $i++) {
        if ($lines[$i].Trim() -ieq "[$Section]") { $sectionStart=$i; break }
    }
    if ($sectionStart -lt 0) {
        $lines.Add("[$Section]"); $lines.Add("$Key=$Value")
    } else {
        for ($i=$sectionStart+1; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match '^\s*\[') { $sectionEnd=$i; break }
        }
        $found=$false
        for ($i=$sectionEnd-1; $i -gt $sectionStart; $i--) {
            if ($lines[$i] -match ('^\s*'+[regex]::Escape($Key)+'\s*=')) {
                if (!$found) { $lines[$i]="$Key=$Value"; $found=$true } else { $lines.RemoveAt($i) }
            }
        }
        if (!$found) { $lines.Insert($sectionStart+1,"$Key=$Value") }
    }
    return ($lines -join "`r`n")
}
function Remove-GamepadBindings([string]$Text) {
    $result = [Collections.Generic.List[string]]::new()
    foreach ($line in ($Text -split '\r\n|\n|\r')) {
        # This preset owns controller 0 buttons/POV and its X/Y/Z/RX/RY axes.
        if ($line -match '^\s*[^=]*(JoystickDevice0|JoystickPov0)\s*=') {
            if ($line -notmatch 'AXE_' -or $line -match 'AXE_(X|Y|Z|RX|RY)\b') { continue }
        }
        if ($line -match '^\s*JoystickDevice0\s+AXE_(X|Y|Z|RX|RY)\s*=') { continue }
        $result.Add($line)
    }
    return ($result -join "`r`n")
}
if (!$GamePath) { $GamePath = Read-Host 'Path to IL-2 1946 folder (contains il2fb.exe)' }
$GamePath = [IO.Path]::GetFullPath($GamePath.Trim('"'))
if (!(Test-Path -LiteralPath (Join-Path $GamePath 'il2fb.exe'))) { throw 'il2fb.exe not found in selected folder.' }
if (Get-Process il2fb -ErrorAction SilentlyContinue) { throw 'Close IL-2 before installation.' }
$conf = Join-Path $GamePath 'conf.ini'
$users = Join-Path $GamePath 'Users'
if (!$Profile) {
    $all = Join-Path $users 'all.ini'
    if (Test-Path -LiteralPath $all) {
        $match = [regex]::Match([IO.File]::ReadAllText($all,$encoding),'(?ms)^\[current\]\s*\r?\n\s*([^\s\[]+)')
        if ($match.Success) { $Profile=$match.Groups[1].Value }
    }
    if (!$Profile) { $Profile=Read-Host 'Pilot profile folder name inside Users (usually 0)' }
}
if ($Profile -notmatch '^[\w-]+$') { throw 'Invalid profile folder name.' }
$relativeProfile = "Users\$Profile\settings.ini"
$settings = Join-Path $GamePath $relativeProfile
if (!(Test-Path -LiteralPath $settings) -or !(Test-Path -LiteralPath $conf)) { throw 'conf.ini or selected pilot settings.ini not found.' }
# Compute everything before modifying files.
$c = [IO.File]::ReadAllText($conf,$encoding)
$s = Remove-GamepadBindings ([IO.File]::ReadAllText($settings,$encoding))
$c = Set-IniValue $c 'game' 'Intro' '0'
$c = Set-IniValue $c 'rts' 'joyUse' '1'
$c = Set-IniValue $c 'rts' 'mouseUse' '2'
$c = Set-IniValue $c 'HotKey gui' 'Escape' 'activate'
$c = Set-IniValue $c 'rts_joystick' 'X' '12 5 10 18 28 40 54 68 80 90 100 0'
$c = Set-IniValue $c 'rts_joystick' 'Y' '12 5 10 18 28 40 54 68 80 90 100 0'
$c = Set-IniValue $c 'rts_joystick' 'RX' '15 5 10 18 28 40 54 68 80 90 100 0'
$bindings = @(
 @('HotKey move','JoystickDevice0 AXE_X','aileron'),
 @('HotKey move','JoystickDevice0 AXE_Y','elevator'),
 @('HotKey move','JoystickDevice0 AXE_Z','-rudder'),
 @('HotKey pilot','Pov270 JoystickPov0','AIRCRAFT_POWER_MINUS_5'),
 @('HotKey pilot','Pov90 JoystickPov0','AIRCRAFT_POWER_PLUS_5'),
 @('HotKey pilot','Pov0 JoystickPov0','AIRCRAFT_FLAPS_NOTCH_UP'),
 @('HotKey pilot','Pov180 JoystickPov0','AIRCRAFT_FLAPS_NOTCH_DOWN'),
 @('HotKey pilot','Joystick0 JoystickDevice0','Weapon01'),
 @('HotKey pilot','Joystick1 JoystickDevice0','Brake'),
 @('HotKey pilot','Joystick2 JoystickDevice0','Weapon1'),
 @('HotKey pilot','Joystick3 JoystickDevice0','Boost'),
 @('HotKey pilot','Joystick4 JoystickDevice0','Weapon2'),
 @('HotKey pilot','Joystick5 JoystickDevice0','Weapon3'),
 @('HotKey pilot','Joystick7 JoystickDevice0','AIRCRAFT_TOGGLE_ENGINE'),
 @('HotKey pilot','G','Gear'),
 @('HotKey aircraftView','Joystick8 JoystickDevice0','cockpitAim'),
 @('HotKey PanView','Joystick9 JoystickDevice0','PanReset'),
 @('HotKey misc','Joystick6 JoystickDevice0','pad')
)
foreach ($b in $bindings) { $s = Set-IniValue $s $b[0] $b[1] $b[2] }
$target = Join-Path $GamePath 'Xbox'
$backup = Join-Path $target ('backups\'+(Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
New-Item -ItemType Directory -Path $backup -Force | Out-Null
Copy-Item -LiteralPath $conf -Destination (Join-Path $backup 'conf.ini')
Copy-Item -LiteralPath $settings -Destination (Join-Path $backup 'settings.ini')
$statePath = Join-Path $target 'install-state.json'
if (Test-Path -LiteralPath $statePath) { Copy-Item -LiteralPath $statePath -Destination (Join-Path $backup 'previous-state.json') }
$payload = Join-Path $PSScriptRoot 'payload'
foreach ($name in @('IL2-Xbox.cmd','Play-IL2-Xbox.ps1')) {
    $existing = Join-Path $target $name
    if (Test-Path -LiteralPath $existing) { Copy-Item -LiteralPath $existing -Destination (Join-Path $backup $name) }
    Copy-Item -LiteralPath (Join-Path $payload $name) -Destination $existing -Force
}
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Restore.ps1') -Destination (Join-Path $target 'Restore.ps1') -Force
[IO.File]::WriteAllText($conf,$c,$encoding)
[IO.File]::WriteAllText($settings,$s,$encoding)
$state = @{Version='1.0.0'; Profile=$relativeProfile; Backup=$backup; Shortcut=$null}
$state | ConvertTo-Json | Set-Content -LiteralPath $statePath -Encoding UTF8
if (!$NoShortcut) {
    try {
        $desktop=[Environment]::GetFolderPath('Desktop')
        $shortcut=Join-Path $desktop 'IL-2 Sturmovik 1946 - Xbox.lnk'
        $wsh=New-Object -ComObject WScript.Shell
        # Do not replace a user shortcut without backing it up.
        if (Test-Path -LiteralPath $shortcut) { Copy-Item -LiteralPath $shortcut -Destination (Join-Path $backup 'desktop.lnk') }
        $link=$wsh.CreateShortcut($shortcut)
        $link.TargetPath=Join-Path $target 'IL2-Xbox.cmd'
        $link.WorkingDirectory=$target
        $link.WindowStyle=7
        $link.IconLocation=(Join-Path $GamePath 'il2fb.exe')+',0'
        foreach ($url in (Get-ChildItem -LiteralPath $desktop -Filter '*.url' -ErrorAction SilentlyContinue)) {
            $u=[IO.File]::ReadAllText($url.FullName)
            if ($u -match 'steam://rungameid/15320' -and $u -match '(?m)^IconFile=(.+)\r?$') {
                $icon=$Matches[1].Trim()
                if (Test-Path -LiteralPath $icon) { $link.IconLocation=$icon+',0' }
                break
            }
        }
        $link.Save()
        $state.Shortcut=$shortcut
        $state | ConvertTo-Json | Set-Content -LiteralPath $statePath -Encoding UTF8
    } catch { Write-Warning "Installed, but desktop shortcut could not be created: $_" }
}
Write-Host "Installed for pilot $Profile. Launch: $target\IL2-Xbox.cmd"
Write-Host "Backup: $backup"