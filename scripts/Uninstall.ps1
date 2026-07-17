[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$Manifest = (Join-Path $HOME '.codex-cli-shared\runtime\codex-zh\install-manifest.json')
)

$ErrorActionPreference = 'Stop'
$manifestPath = (Resolve-Path -LiteralPath $Manifest).Path
$data = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$currentHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $data.launcher).Hash.ToLowerInvariant()
if ($currentHash -ne [string]$data.installedLauncherSha256) {
    throw 'Launcher changed after installation. Refusing to overwrite it; restore the recorded backup manually after review.'
}
$backupHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $data.backup).Hash.ToLowerInvariant()
if ($backupHash -ne [string]$data.originalLauncherSha256) {
    throw 'Launcher backup hash mismatch. Refusing to uninstall.'
}

if ($PSCmdlet.ShouldProcess($data.launcher, "Restore official Codex CLI launcher")) {
    Copy-Item -LiteralPath $data.backup -Destination $data.launcher -Force
    $restoredHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $data.launcher).Hash.ToLowerInvariant()
    if ($restoredHash -ne [string]$data.originalLauncherSha256) { throw 'Restored launcher hash mismatch.' }
    $auditManifest = Join-Path (Split-Path -Parent $data.backup) "install-manifest.uninstalled-$([DateTimeOffset]::Now.ToString('yyyyMMdd-HHmmss')).json"
    Copy-Item -LiteralPath $manifestPath -Destination $auditManifest
    if (Test-Path -LiteralPath $data.executable) { Remove-Item -LiteralPath $data.executable -Force }
    $versionDirectory = Split-Path -Parent $data.executable
    if ((Test-Path -LiteralPath $versionDirectory) -and -not (Get-ChildItem -LiteralPath $versionDirectory -Force)) {
        Remove-Item -LiteralPath $versionDirectory -Force
    }
    Remove-Item -LiteralPath $manifestPath -Force
    Write-Output 'Official Codex CLI launcher restored and the localized runtime was removed.'
}
