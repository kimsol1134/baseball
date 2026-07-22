$ErrorActionPreference = "Stop"

$bundleRoot = Join-Path $PSScriptRoot "../apps/windows/src-tauri/target/release/bundle"
$installer = Get-ChildItem (Join-Path $bundleRoot "nsis") -Filter "*-setup.exe" | Select-Object -First 1
if (-not $installer) { throw "NSIS installer was not produced." }

$install = Start-Process -FilePath $installer.FullName -ArgumentList "/S" -PassThru -Wait
if ($install.ExitCode -ne 0) { throw "NSIS installation failed with exit code $($install.ExitCode)." }

$installRoots = Get-ChildItem $env:LOCALAPPDATA -Directory |
    Where-Object { $_.Name -like "*야구*환생함*" -or $_.Name -like "*baseball*" } |
    Sort-Object LastWriteTime -Descending
$installRoot = $installRoots | Select-Object -First 1
if (-not $installRoot) { throw "Installed application directory was not found." }

try {
    $sidecar = Get-ChildItem $installRoot.FullName -Recurse -Filter "simulation-sidecar*.exe" | Select-Object -First 1
    if (-not $sidecar) { throw "Installed Swift sidecar was not found." }
    $runtime = Join-Path $installRoot.FullName "swift-runtime"
    if (-not (Test-Path (Join-Path $runtime "swiftCore.dll"))) { throw "Installed Swift runtime was not found." }

    $previousPath = $env:PATH
    try {
        $env:PATH = "$runtime;$previousPath"
        $request = '{"jsonrpc":"2.0","id":"installed-smoke","method":"health"}'
        $output = $request | & $sidecar.FullName
        if ($LASTEXITCODE -ne 0) { throw "Installed sidecar exited with $LASTEXITCODE." }
        $response = $output | Select-Object -First 1 | ConvertFrom-Json
        if ($response.error -or $response.result.status -ne "ok") {
            throw "Installed sidecar health check failed: $output"
        }
        Write-Host "Installed package health check passed: core $($response.result.coreVersion)"
    }
    finally {
        $env:PATH = $previousPath
    }
}
finally {
    $uninstaller = Get-ChildItem $installRoot.FullName -Filter "uninstall*.exe" | Select-Object -First 1
    if ($uninstaller) {
        $uninstall = Start-Process -FilePath $uninstaller.FullName -ArgumentList "/S" -PassThru -Wait
        if ($uninstall.ExitCode -ne 0) { Write-Warning "Uninstaller exited with $($uninstall.ExitCode)." }
    }
}
