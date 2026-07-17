[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Version,
    [Parameter(Mandatory)][string]$RustToolchain,
    [Parameter(Mandatory)][string]$UpstreamRoot
)

$ErrorActionPreference = 'Stop'
$upstream = (Resolve-Path -LiteralPath $UpstreamRoot).Path
$cargoRoot = Join-Path $upstream 'codex-rs'
$lockFile = Join-Path $cargoRoot 'Cargo.lock'
$backup = Join-Path ([IO.Path]::GetTempPath()) "Codex-Cargo.lock-$([guid]::NewGuid().ToString('N'))"
Copy-Item -LiteralPath $lockFile -Destination $backup

try {
    Push-Location $cargoRoot
    try {
        & rustup run $RustToolchain cargo metadata --no-deps --format-version 1 | Out-Null
        if ($LASTEXITCODE -ne 0) { throw 'Cargo metadata failed while refreshing workspace lock versions.' }
    } finally {
        Pop-Location
    }

    $diff = @(& git -C $upstream diff --unified=0 -- codex-rs/Cargo.lock)
    if ($LASTEXITCODE -ne 0) { throw 'Could not inspect Cargo.lock changes.' }
    $removed = @($diff | Where-Object { $_ -match '^-' -and $_ -notmatch '^---' } | ForEach-Object { $_.Substring(1) })
    $added = @($diff | Where-Object { $_ -match '^\+' -and $_ -notmatch '^\+\+\+' } | ForEach-Object { $_.Substring(1) })
    if ($removed.Count -eq 0 -or $removed.Count -ne $added.Count) {
        throw "Unexpected Cargo.lock change count: removed=$($removed.Count), added=$($added.Count)."
    }

    for ($index = 0; $index -lt $removed.Count; $index++) {
        $oldLine = $removed[$index]
        $newLine = $added[$index]
        if ($oldLine -notmatch '^\s*(version = "0\.0\.0"|"[^"]+ 0\.0\.0",)$') {
            throw "Unexpected Cargo.lock removal: $oldLine"
        }
        if ($oldLine.Replace('0.0.0', $Version) -ne $newLine) {
            throw "Unexpected Cargo.lock replacement: $oldLine -> $newLine"
        }
    }

    [pscustomobject]@{
        WorkspaceVersionChanges = $removed.Count
        BeforeSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $backup).Hash.ToLowerInvariant()
        AfterSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $lockFile).Hash.ToLowerInvariant()
    } | Format-List
} catch {
    Copy-Item -LiteralPath $backup -Destination $lockFile -Force
    throw
} finally {
    Remove-Item -LiteralPath $backup -Force -ErrorAction SilentlyContinue
}
