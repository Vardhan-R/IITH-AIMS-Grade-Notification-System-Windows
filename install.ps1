$ErrorActionPreference = "Stop"

$AppDir = Join-Path $env:USERPROFILE ".aims-notifs"
$BinDir = Join-Path $env:LOCALAPPDATA "Programs\IITH AIMS Grade Notification System\bin"
$CliScript = Join-Path $BinDir "aims-notifs.ps1"
$CliCmd = Join-Path $BinDir "aims-notifs.cmd"
$CompletionMarker = "# aims-notifs completion"

Write-Host "Installing IITH AIMS Grade Notification System..."

New-Item -ItemType Directory -Force -Path $AppDir | Out-Null
New-Item -ItemType Directory -Force -Path $BinDir | Out-Null

Copy-Item -Path (Join-Path $PSScriptRoot "main.py") -Destination $AppDir -Force
Copy-Item -Path (Join-Path $PSScriptRoot "requirements.txt") -Destination $AppDir -Force
Copy-Item -Path (Join-Path $PSScriptRoot "setup.py") -Destination $AppDir -Force
Copy-Item -Path (Join-Path $PSScriptRoot "aims-notifs.ps1") -Destination $CliScript -Force

@(
    "@echo off"
    "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"%~dp0aims-notifs.ps1`" %*"
) | Set-Content -Path $CliCmd -Encoding ASCII

if ($PROFILE -and -not (Test-Path $PROFILE)) {
    New-Item -ItemType File -Path $PROFILE -Force | Out-Null
}

if ($PROFILE -and -not (Select-String -Path $PROFILE -Pattern $CompletionMarker -SimpleMatch -Quiet)) {
    @"

$CompletionMarker
Register-ArgumentCompleter -Native -CommandName aims-notifs -ScriptBlock {
    param(`$commandName, `$wordToComplete, `$cursorPosition, `$commandAst, `$fakeBoundParameter)
    `$commands = @('setup', 'start', 'stop', 'status', 'run-now', 'logs', 'uninstall')
    `$commands | Where-Object { `$_ -like "`$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new(`$_, `$_, 'ParameterValue', `$_)
    }
}
"@ | Add-Content -Path $PROFILE
}

Write-Host ""
Write-Host "Installation complete."
Write-Host ""

$pathEntries = $env:PATH -split ';' | Where-Object { $_ -ne '' }
if ($pathEntries -notcontains $BinDir) {
    Write-Host "Adding $BinDir to the PATH environment variable..."
    [Environment]::SetEnvironmentVariable('Path', "$BinDir;$([Environment]::GetEnvironmentVariable('Path', 'User'))", 'User')
    Write-Host ""
    Write-Host "PATH environment variable updated."
    Write-Host ""
    Write-Host "Please restart your PowerShell session for the changes to take effect."
    exit 0
}

Write-Host "Next steps:"
Write-Host "  Create an App Password (on the email ID to which you want to receive notifications)"
Write-Host "    Refer to https://support.google.com/mail/answer/185833"
Write-Host "  Switch on IITH VPN, and keep it on (if applicable)"
Write-Host "    Refer to https://docs.google.com/document/u/0/d/e/2PACX-1vQxWGsv6dhwmvx4Efq17CPyCBTvMiKd9oTJecNDy51KXIPDfdjUQq822EpBExduoPtBTQbkvtNMudqh/pub"
Write-Host "  Run aims-notifs setup"
