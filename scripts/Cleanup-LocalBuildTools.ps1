[CmdletBinding(SupportsShouldProcess)]
param()

$ErrorActionPreference = 'Stop'

$buildProcesses = @(Get-Process cargo-xwin, cargo, rustc, clang-cl, lld-link, rustup -ErrorAction SilentlyContinue)
if ($buildProcesses.Count -gt 0) {
    throw "Build processes are still running: $($buildProcesses.ProcessName -join ', ')"
}

function Remove-ExactTree {
    param([Parameter(Mandatory)][string]$Path)

    $full = [IO.Path]::GetFullPath($Path).TrimEnd('\')
    $blocked = @(
        [IO.Path]::GetPathRoot($full).TrimEnd('\'),
        [IO.Path]::GetFullPath($HOME).TrimEnd('\'),
        [IO.Path]::GetFullPath($env:LOCALAPPDATA).TrimEnd('\'),
        [IO.Path]::GetFullPath($env:TEMP).TrimEnd('\')
    )
    if ($blocked -contains $full) { throw "Unsafe cleanup target: $full" }
    if (Test-Path -LiteralPath $full) {
        if ($PSCmdlet.ShouldProcess($full, 'Remove verified Codex CLI build dependency/cache')) {
            Remove-Item -LiteralPath $full -Recurse -Force
        }
    }
}

$cargoHome = Join-Path $HOME '.cargo'
if (Test-Path -LiteralPath $cargoHome) {
    $allowedCargoEntries = @(
        'bin', 'registry', '.crates.toml', '.crates2.json', '.global-cache',
        '.package-cache', '.package-cache-mutate'
    )
    $unexpected = @(Get-ChildItem -LiteralPath $cargoHome -Force | Where-Object {
        $allowedCargoEntries -notcontains $_.Name
    })
    if ($unexpected.Count -gt 0) {
        throw "Unexpected files in .cargo; refusing cleanup: $($unexpected.Name -join ', ')"
    }
}

$rustupHome = Join-Path $HOME '.rustup'
if (Test-Path -LiteralPath $rustupHome) {
    $allowedRustupEntries = @('downloads', 'tmp', 'toolchains', 'update-hashes', 'settings.toml')
    $unexpected = @(Get-ChildItem -LiteralPath $rustupHome -Force | Where-Object {
        $allowedRustupEntries -notcontains $_.Name
    })
    if ($unexpected.Count -gt 0) {
        throw "Unexpected files in .rustup; refusing cleanup: $($unexpected.Name -join ', ')"
    }
}

$rustup = Join-Path $cargoHome 'bin\rustup.exe'
if (Test-Path -LiteralPath $rustup) {
    foreach ($toolchain in @('1.95.0-x86_64-pc-windows-msvc', 'stable-x86_64-pc-windows-msvc')) {
        if ($PSCmdlet.ShouldProcess($toolchain, 'Uninstall Rust toolchain added for Codex CLI build')) {
            & $rustup toolchain uninstall $toolchain
            if ($LASTEXITCODE -ne 0) { throw "Failed to uninstall Rust toolchain: $toolchain" }
        }
    }
}

$llvm = Join-Path $env:LOCALAPPDATA 'Programs\LLVM-CodexBuild-22.1.8'
$llvmUninstaller = Join-Path $llvm 'Uninstall.exe'
if ((Test-Path -LiteralPath $llvmUninstaller) -and $PSCmdlet.ShouldProcess($llvm, 'Run LLVM user-level uninstaller')) {
    $process = Start-Process -FilePath $llvmUninstaller -ArgumentList '/S' -PassThru -Wait -WindowStyle Hidden
    if ($process.ExitCode -ne 0) { throw "LLVM uninstaller failed: $($process.ExitCode)" }
}

foreach ($target in @(
    (Join-Path $env:TEMP 'Codex-CLI-Chinese'),
    $llvm,
    (Join-Path $env:LOCALAPPDATA 'cargo-xwin'),
    (Join-Path $HOME '.codex-cli-shared\build-tools\cargo-xwin-0.23.0'),
    (Join-Path $HOME '.codex-cli-shared\build-cache\codex-source'),
    $cargoHome,
    (Join-Path $rustupHome 'downloads'),
    (Join-Path $rustupHome 'tmp'),
    (Join-Path $rustupHome 'toolchains'),
    (Join-Path $rustupHome 'update-hashes')
)) {
    Remove-ExactTree -Path $target
}

if (Test-Path -LiteralPath $rustupHome) {
    $settings = "version = `"12`"`r`nprofile = `"minimal`"`r`n`r`n[overrides]`r`n"
    if ($PSCmdlet.ShouldProcess((Join-Path $rustupHome 'settings.toml'), 'Restore pre-existing Rustup settings')) {
        [IO.File]::WriteAllText((Join-Path $rustupHome 'settings.toml'), $settings, [Text.UTF8Encoding]::new($false))
    }
}

Write-Output 'Local Codex CLI Chinese build dependencies and caches were removed.'
