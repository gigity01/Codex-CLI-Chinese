[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$BuiltBinary,
    [string]$Launcher = (Join-Path $HOME '.codex-cli-bin\codex-cli.cmd'),
    [string]$Version
)

$ErrorActionPreference = 'Stop'
if (-not $BuiltBinary) {
    $candidates = @(Get-ChildItem -LiteralPath $PSScriptRoot -File -Filter 'codex-zh-*-windows-x64.exe')
    if ($candidates.Count -ne 1) {
        throw "Expected one codex-zh-*-windows-x64.exe beside Install.ps1, found $($candidates.Count)."
    }
    $BuiltBinary = $candidates[0].FullName
}
$binary = (Resolve-Path -LiteralPath $BuiltBinary).Path
$launcherPath = (Resolve-Path -LiteralPath $Launcher).Path
$versionOutput = & $binary --version
if ($LASTEXITCODE -ne 0 -or $versionOutput -notmatch 'codex-cli\s+(?<version>\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?)') {
    throw "Executable version check failed: $versionOutput"
}
$detectedVersion = $Matches.version
if ($Version -and $Version -ne $detectedVersion) {
    throw "Requested version $Version does not match executable version $detectedVersion."
}
$Version = $detectedVersion

$sourceLine = 'set "CODEX_CLI=%REAL_USERPROFILE%\.codex-cli-node\codex.cmd"'
$targetRelative = ".codex-cli-shared\runtime\codex-zh\$Version\codex-zh.exe"
$targetLine = "set `"CODEX_CLI=%REAL_USERPROFILE%\$targetRelative`""
$launcherText = Get-Content -LiteralPath $launcherPath -Raw
$officialMatches = ([regex]::Matches($launcherText, [regex]::Escape($sourceLine))).Count
$localizedPattern = 'set "CODEX_CLI=%REAL_USERPROFILE%\\\.codex-cli-shared\\runtime\\codex-zh\\[^\\"]+\\codex-zh\.exe"'
$localizedMatches = ([regex]::Matches($launcherText, $localizedPattern)).Count
if (($officialMatches + $localizedMatches) -ne 1) {
    throw "Expected one supported CODEX_CLI line, found official=$officialMatches localized=$localizedMatches."
}

$stamp = [DateTimeOffset]::Now.ToString('yyyyMMdd-HHmmss')
$archiveDir = Join-Path $HOME ".codex-cli-archive\codex-cli-chinese\$stamp"
$runtimeDir = Join-Path $HOME ".codex-cli-shared\runtime\codex-zh\$Version"
$installedBinary = Join-Path $runtimeDir 'codex-zh.exe'
$manifestPath = Join-Path $HOME '.codex-cli-shared\runtime\codex-zh\install-manifest.json'

if ($PSCmdlet.ShouldProcess($launcherPath, "Install Codex CLI Chinese $Version")) {
    New-Item -ItemType Directory -Path $archiveDir, $runtimeDir -Force | Out-Null
    $backup = Join-Path $archiveDir 'codex-cli.cmd'
    if ($localizedMatches -eq 1) {
        if (-not (Test-Path -LiteralPath $manifestPath)) { throw 'Existing localized launcher has no install manifest.' }
        $previous = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
        $currentHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $launcherPath).Hash.ToLowerInvariant()
        if ($currentHash -ne [string]$previous.installedLauncherSha256) { throw 'Localized launcher changed after installation.' }
        $originalHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $previous.backup).Hash.ToLowerInvariant()
        if ($originalHash -ne [string]$previous.originalLauncherSha256) { throw 'Previous original launcher backup hash mismatch.' }
        Copy-Item -LiteralPath $previous.backup -Destination $backup
        $launcherText = Get-Content -LiteralPath $backup -Raw
    } else {
        Copy-Item -LiteralPath $launcherPath -Destination $backup
    }
    Copy-Item -LiteralPath $binary -Destination $installedBinary -Force
    $updated = $launcherText.Replace($sourceLine, $targetLine)
    $tempFile = Join-Path ([IO.Path]::GetTempPath()) "codex-cli-$([guid]::NewGuid().ToString('N')).cmd"
    [IO.File]::WriteAllText($tempFile, $updated, [Text.UTF8Encoding]::new($false))
    Copy-Item -LiteralPath $tempFile -Destination $launcherPath -Force
    Remove-Item -LiteralPath $tempFile -Force

    $manifest = [ordered]@{
        schemaVersion = 1
        version = $Version
        installedAt = [DateTimeOffset]::Now.ToString('o')
        launcher = $launcherPath
        backup = $backup
        originalLauncherSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $backup).Hash.ToLowerInvariant()
        installedLauncherSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $launcherPath).Hash.ToLowerInvariant()
        executable = $installedBinary
        executableSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $installedBinary).Hash.ToLowerInvariant()
    }
    $manifest | ConvertTo-Json | Set-Content -LiteralPath $manifestPath -Encoding utf8
    Write-Output "Installed Codex CLI Chinese $Version. Backup: $backup"
}
