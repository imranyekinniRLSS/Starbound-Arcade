param(
    [Parameter(Mandatory = $true)]
    [string]$FirebaseAuthUid
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$functionsDir = Join-Path $repoRoot 'functions'

if (-not (Test-Path $functionsDir)) {
    throw "Functions folder not found: $functionsDir"
}

Set-Location $functionsDir

Write-Host 'Installing Cloud Functions dependencies...'
npm install

Write-Host 'Sign in with your Google Application Default Credentials...'
gcloud auth application-default login

Write-Host "Granting moderator access to UID: $FirebaseAuthUid"
node scripts/set-moderator.js $FirebaseAuthUid

Write-Host 'Moderation access updated.'
Write-Host 'The user must sign out and sign back in before the moderator tab is authorized.'
