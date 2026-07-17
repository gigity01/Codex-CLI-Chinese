[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$scripts = @(
    'Build.ps1', 'Check-Version.ps1', 'Cleanup-LocalBuildTools.ps1',
    'Install.ps1', 'Package-CI.ps1', 'Uninstall.ps1'
)

foreach ($name in $scripts) {
    $tokens = $null
    $errors = $null
    $path = Join-Path $PSScriptRoot $name
    [void][Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$errors)
    if ($errors.Count -gt 0) { throw "$name has PowerShell parse errors: $($errors.Message -join '; ')" }
}

$root = Join-Path ([IO.Path]::GetTempPath()) "Codex-CLI-Chinese-script-test-$([guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Path $root -Force | Out-Null
try {
    $fakeBinary = Join-Path $root 'fake-codex.cmd'
    [IO.File]::WriteAllText($fakeBinary, "@echo codex-cli 0.144.3`r`n", [Text.ASCIIEncoding]::new())
    $launcher = Join-Path $root 'codex-cli.cmd'
    $launcherText = @'
@echo off
set "REAL_USERPROFILE=%USERPROFILE%"
set "CODEX_CLI=%REAL_USERPROFILE%\.codex-cli-node\codex.cmd"
call "%CODEX_CLI%" %*
'@
    [IO.File]::WriteAllText($launcher, $launcherText, [Text.UTF8Encoding]::new($false))
    & (Join-Path $PSScriptRoot 'Install.ps1') -BuiltBinary $fakeBinary -Launcher $launcher -WhatIf
    if ($LASTEXITCODE -ne 0) { throw 'Install.ps1 WhatIf contract failed.' }
    if ((Get-Content -LiteralPath $launcher -Raw) -ne $launcherText) { throw 'Install.ps1 WhatIf changed the launcher.' }

    $localizedText = $launcherText.Replace(
        'set "CODEX_CLI=%REAL_USERPROFILE%\.codex-cli-node\codex.cmd"',
        'set "CODEX_CLI=%REAL_USERPROFILE%\.codex-cli-shared\runtime\codex-zh\0.143.0\codex-zh.exe"'
    )
    [IO.File]::WriteAllText($launcher, $localizedText, [Text.UTF8Encoding]::new($false))
    & (Join-Path $PSScriptRoot 'Install.ps1') -BuiltBinary $fakeBinary -Launcher $launcher -WhatIf
    if ($LASTEXITCODE -ne 0) { throw 'Install.ps1 localized-update WhatIf contract failed.' }
} finally {
    if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
}

Write-Output 'PowerShell script contracts passed.'
