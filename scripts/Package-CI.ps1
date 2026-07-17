[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Version,
    [Parameter(Mandatory)][string]$UpstreamRoot,
    [string]$OutputDirectory = (Join-Path (Split-Path -Parent $PSScriptRoot) 'out')
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$adapterPath = Join-Path $projectRoot "resources\adapters\codex-$Version.json"
$adapter = Get-Content -LiteralPath $adapterPath -Raw | ConvertFrom-Json
$upstream = (Resolve-Path -LiteralPath $UpstreamRoot).Path
$binary = Join-Path $upstream 'codex-rs\target\release\codex.exe'
if (-not (Test-Path -LiteralPath $binary)) { throw "Built executable not found: $binary" }

$versionOutput = & $binary --version
if ($LASTEXITCODE -ne 0 -or $versionOutput -notmatch "codex-cli\s+$([regex]::Escape($Version))") {
    throw "Built executable version check failed: $versionOutput"
}

$commit = (& git -C $upstream rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $commit -ne [string]$adapter.upstream.commitSha) {
    throw "Upstream commit mismatch: $commit"
}

New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$outputName = "codex-zh-$Version-windows-x64.exe"
$output = Join-Path $OutputDirectory $outputName
Copy-Item -LiteralPath $binary -Destination $output -Force
Copy-Item -LiteralPath (Join-Path $projectRoot 'scripts\Install.ps1') -Destination $OutputDirectory -Force
Copy-Item -LiteralPath (Join-Path $projectRoot 'scripts\Uninstall.ps1') -Destination $OutputDirectory -Force
Copy-Item -LiteralPath (Join-Path $projectRoot 'LICENSE') -Destination $OutputDirectory -Force
Copy-Item -LiteralPath (Join-Path $projectRoot 'THIRD_PARTY_NOTICES.md') -Destination $OutputDirectory -Force
Copy-Item -LiteralPath (Join-Path $projectRoot 'docs\ARTIFACT_USAGE.zh-CN.md') -Destination $OutputDirectory -Force

$hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $output).Hash.ToLowerInvariant()
"$hash  $outputName" | Set-Content -LiteralPath (Join-Path $OutputDirectory 'SHA256SUMS.txt') -Encoding utf8
[ordered]@{
    schemaVersion = 1
    project = 'Codex-CLI-Chinese'
    version = $Version
    upstreamRepository = [string]$adapter.upstream.repository
    upstreamTag = [string]$adapter.upstream.tag
    upstreamCommit = $commit
    adapterId = [string]$adapter.id
    translationOperations = @($adapter.operations).Count
    target = [string]$adapter.upstream.target
    executable = $outputName
    executableSha256 = $hash
    builtAt = [DateTimeOffset]::UtcNow.ToString('o')
} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $OutputDirectory 'build-manifest.json') -Encoding utf8

Write-Output $output
