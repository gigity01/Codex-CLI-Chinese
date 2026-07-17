[CmdletBinding()]
param(
    [string]$SourceRoot,
    [string]$SourceArchive,
    [string]$ProjectRoot,
    [string]$Adapter,
    [string]$Locale,
    [string]$CargoXwin,
    [string]$LlvmBin
)

$ErrorActionPreference = 'Stop'
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $ProjectRoot) { $ProjectRoot = Split-Path -Parent $scriptRoot }
if (-not $Adapter) { $Adapter = Join-Path $ProjectRoot 'resources\adapters\codex-0.144.3.json' }
if (-not $Locale) { $Locale = Join-Path $ProjectRoot 'resources\locales\zh-CN.json' }
if (-not $CargoXwin) { $CargoXwin = Join-Path $HOME '.codex-cli-shared\build-tools\cargo-xwin-0.23.0\cargo-xwin.exe' }
if (-not $LlvmBin) { $LlvmBin = Join-Path $env:LOCALAPPDATA 'Programs\LLVM-CodexBuild-22.1.8\bin' }
$project = (Resolve-Path -LiteralPath $ProjectRoot).Path
$xwin = (Resolve-Path -LiteralPath $CargoXwin).Path
$llvm = (Resolve-Path -LiteralPath $LlvmBin).Path
$adapterData = Get-Content -LiteralPath $Adapter -Raw | ConvertFrom-Json
$version = [string]$adapterData.upstream.version
$workRoot = Join-Path ([IO.Path]::GetTempPath()) "Codex-CLI-Chinese\build-$version-$([guid]::NewGuid().ToString('N'))"
$targetDir = Join-Path $workRoot 'target'
$distDir = Join-Path $project 'dist'

New-Item -ItemType Directory -Path $workRoot, $targetDir, $distDir -Force | Out-Null
if ($SourceArchive) {
    $archive = (Resolve-Path -LiteralPath $SourceArchive).Path
    $archiveHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $archive).Hash.ToLowerInvariant()
    if ($archiveHash -ne [string]$adapterData.upstream.sourceArchiveSha256) {
        throw "Source archive SHA-256 mismatch: $archiveHash"
    }
    $extractRoot = Join-Path $workRoot 'upstream'
    Expand-Archive -LiteralPath $archive -DestinationPath $extractRoot
    $candidates = @(Get-ChildItem -LiteralPath $extractRoot -Directory | Where-Object {
        Test-Path -LiteralPath (Join-Path $_.FullName 'codex-rs\Cargo.toml')
    })
    if ($candidates.Count -ne 1) { throw "Expected one extracted source root, found $($candidates.Count)." }
    $patchedSource = $candidates[0].FullName
} elseif ($SourceRoot) {
    $source = (Resolve-Path -LiteralPath $SourceRoot).Path
    $patchedSource = Join-Path $workRoot 'source'
    New-Item -ItemType Directory -Path $patchedSource -Force | Out-Null
    & robocopy.exe $source $patchedSource /E /COPY:DAT /DCOPY:DAT /R:1 /W:1 /NFL /NDL /NJH /NJS /NP
    if ($LASTEXITCODE -gt 7) { throw "Source copy failed with robocopy exit code $LASTEXITCODE." }
} else {
    throw 'Provide either -SourceArchive or -SourceRoot.'
}
$cargoToml = Join-Path $patchedSource 'codex-rs\Cargo.toml'
if (-not (Test-Path -LiteralPath $cargoToml)) { throw "Source copy is incomplete: $cargoToml" }

& node (Join-Path $project 'src\cli.mjs') apply --source $patchedSource --adapter $Adapter --locale $Locale
if ($LASTEXITCODE -ne 0) { throw 'Localization adapter failed.' }

$env:PATH = "$llvm;$(Join-Path $HOME '.cargo\bin');$env:PATH"
$env:CARGO_TARGET_DIR = $targetDir
Push-Location (Join-Path $patchedSource 'codex-rs')
try {
    & $xwin build --target x86_64-pc-windows-msvc --release --locked -p codex-cli --bin codex --target-dir $targetDir
    if ($LASTEXITCODE -ne 0) { throw 'cargo-xwin build failed.' }
} finally {
    Pop-Location
}

$built = Join-Path $targetDir 'x86_64-pc-windows-msvc\release\codex.exe'
if (-not (Test-Path -LiteralPath $built)) { throw "Built executable was not found: $built" }
$output = Join-Path $distDir "codex-zh-$version-x86_64-pc-windows-msvc.exe"
Copy-Item -LiteralPath $built -Destination $output -Force
$versionOutput = & $output --version
if ($LASTEXITCODE -ne 0 -or $versionOutput -notmatch [regex]::Escape($version)) {
    throw "Built executable version check failed: $versionOutput"
}

$manifest = [ordered]@{
    schemaVersion = 1
    adapterId = $adapterData.id
    upstreamVersion = $version
    upstreamTag = $adapterData.upstream.tag
    upstreamCommit = $adapterData.upstream.commitSha
    executable = $output
    executableSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $output).Hash.ToLowerInvariant()
    builtAt = [DateTimeOffset]::Now.ToString('o')
}
$manifest | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $distDir "codex-zh-$version.manifest.json") -Encoding utf8
Write-Output $output
