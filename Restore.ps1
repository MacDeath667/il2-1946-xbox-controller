param([string]$GamePath, [switch]$Yes)
$ErrorActionPreference='Stop'
if (!$GamePath) {
    if (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'install-state.json')) { $GamePath=Split-Path -Parent $PSScriptRoot }
    else { $GamePath=Read-Host 'Path to IL-2 1946 folder' }
}
$GamePath=[IO.Path]::GetFullPath($GamePath.Trim('"'))
if (Get-Process il2fb -ErrorAction SilentlyContinue) { throw 'Close IL-2 before restoring.' }
$target=Join-Path $GamePath 'Xbox'
$statePath=Join-Path $target 'install-state.json'
$state=Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
$backup=[IO.Path]::GetFullPath($state.Backup)
$allowed=[IO.Path]::GetFullPath((Join-Path $target 'backups'))+[IO.Path]::DirectorySeparatorChar
if (!$backup.StartsWith($allowed,[StringComparison]::OrdinalIgnoreCase)) { throw 'Invalid backup location.' }
if ($state.Profile -notmatch '^Users\\[\w-]+\\settings\.ini$') { throw 'Invalid profile path.' }
foreach ($name in @('conf.ini','settings.ini')) {
    if (!(Test-Path -LiteralPath (Join-Path $backup $name))) { throw 'Backup is incomplete.' }
}
if (!$Yes) {
    Write-Host 'Restores entire conf.ini and pilot settings.ini from the latest install backup.'
    Write-Host 'Changes made in those files after installation will be replaced.'
    if ((Read-Host 'Type RESTORE to continue') -cne 'RESTORE') { exit }
}
# Preserve the current files as well, before replacing them.
$preRestore=Join-Path $target ('backups\before-restore-'+(Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
New-Item -ItemType Directory -Path $preRestore -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $GamePath 'conf.ini') -Destination (Join-Path $preRestore 'conf.ini')
Copy-Item -LiteralPath (Join-Path $GamePath $state.Profile) -Destination (Join-Path $preRestore 'settings.ini')
Copy-Item -LiteralPath (Join-Path $backup 'conf.ini') -Destination (Join-Path $GamePath 'conf.ini') -Force
Copy-Item -LiteralPath (Join-Path $backup 'settings.ini') -Destination (Join-Path $GamePath $state.Profile) -Force
foreach ($name in @('IL2-Xbox.cmd','Play-IL2-Xbox.ps1')) {
    if (Test-Path -LiteralPath (Join-Path $backup $name)) {
        Copy-Item -LiteralPath (Join-Path $backup $name) -Destination (Join-Path $target $name) -Force
    }
}
if ($state.Shortcut -and (Test-Path -LiteralPath $state.Shortcut)) {
    $wsh=New-Object -ComObject WScript.Shell
    $link=$wsh.CreateShortcut($state.Shortcut)
    if ($link.TargetPath -eq (Join-Path $target 'IL2-Xbox.cmd')) {
        if (Test-Path -LiteralPath (Join-Path $backup 'desktop.lnk')) {
            Copy-Item -LiteralPath (Join-Path $backup 'desktop.lnk') -Destination $state.Shortcut -Force
        } else { Remove-Item -LiteralPath $state.Shortcut }
    }
}
if (Test-Path -LiteralPath (Join-Path $backup 'previous-state.json')) {
    Copy-Item -LiteralPath (Join-Path $backup 'previous-state.json') -Destination $statePath -Force
} else { Remove-Item -LiteralPath $statePath }
Write-Host 'Settings restored. Xbox helper files and backups were kept for manual removal.'
Write-Host "Pre-restore files: $preRestore"