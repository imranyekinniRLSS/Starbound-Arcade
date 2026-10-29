param(
    [string]$ProjectId = 'sign-up-login-82aee',
    [int]$Port = 2563,
    [switch]$NoBrowser
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

$emulatorCommand = @"
Set-Location '$repoRoot'
firebase emulators:start --project $ProjectId
"@

$httpCommand = @"
Set-Location '$repoRoot'
npx http-server . -p $Port
"@

Write-Host 'Starting Firebase emulators in a new terminal...'
Start-Process powershell -ArgumentList '-NoExit', '-Command', $emulatorCommand

Write-Host "Starting local web server on http://localhost:$Port ..."
Start-Process powershell -ArgumentList '-NoExit', '-Command', $httpCommand

if (-not $NoBrowser) {
    Start-Process "http://localhost:$Port"
}

Write-Host 'Keep both terminals open while developing.'
Write-Host 'Use Ctrl+C in each terminal to stop them.'
