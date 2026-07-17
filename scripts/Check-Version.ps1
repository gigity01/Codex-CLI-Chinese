[CmdletBinding()]
param(
    [string]$PackageJson = (Join-Path $HOME '.codex-cli-node\node_modules\@openai\codex\package.json'),
    [string]$ProjectRoot
)

$ErrorActionPreference = 'Stop'
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $ProjectRoot) { $ProjectRoot = Split-Path -Parent $scriptRoot }
$package = Get-Content -LiteralPath $PackageJson -Raw | ConvertFrom-Json
$version = [string]$package.version
$adapter = Join-Path $ProjectRoot "resources\adapters\codex-$version.json"
[pscustomobject]@{
    InstalledOfficialVersion = $version
    AdapterAvailable = Test-Path -LiteralPath $adapter
    AdapterPath = $adapter
    Action = if (Test-Path -LiteralPath $adapter) { 'Version is supported; run check, build, isolated test, then install.' } else { 'Do not patch. Add and verify a new exact-version adapter first.' }
}
