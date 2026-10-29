param(
    [string]$ProjectId = 'sign-up-login-82aee',
    [int]$LocalPort = 2563,
    [switch]$SkipDeploy,
    [switch]$SkipOpenBrowser,
    [string]$FirebaseAuthUid = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $repoRoot

Write-Host '=================================================='
Write-Host ' Starbound Arcade Firebase setup'
Write-Host '=================================================='
Write-Host "Project: $ProjectId"
Write-Host "Root: $repoRoot"
Write-Host "Local port: $LocalPort"
Write-Host ''

if (-not (Get-Command firebase -ErrorAction SilentlyContinue)) {
    Write-Host 'Installing Firebase CLI...'
    npm install --global firebase-tools
}

Write-Host 'Signing in to Firebase...'
firebase login

if (-not $SkipDeploy) {
    Write-Host 'Deploying Firebase rules, indexes, and functions...'
    firebase deploy --project $ProjectId --only firestore:rules,firestore:indexes,functions
}
else {
    Write-Host 'Skipping Firebase deploy as requested.'
}

$functionsDir = Join-Path $repoRoot 'functions'
if (Test-Path $functionsDir) {
    Write-Host 'Installing functions dependencies...'
    Set-Location $functionsDir
    npm install
    Set-Location $repoRoot
}
else {
    Write-Host 'No functions directory found; skipping npm install for functions.'
}

Write-Host 'Starting Firebase emulators in a new terminal...'
$emulatorCommand = @"
Set-Location '$repoRoot'
firebase emulators:start --project $ProjectId
"@
Start-Process powershell -ArgumentList '-NoExit', '-Command', $emulatorCommand

Write-Host "Starting local web server on http://localhost:$LocalPort ..."
$httpCommand = @"
Set-Location '$repoRoot'
npx http-server . -p $LocalPort
"@
Start-Process powershell -ArgumentList '-NoExit', '-Command', $httpCommand

if (-not $SkipOpenBrowser) {
    Start-Process "http://localhost:$LocalPort"
}

Write-Host ''
Write-Host 'Setup is running.'
Write-Host 'Keep both terminals open while developing.'
Write-Host 'If you want to grant moderator access, run:'
Write-Host '  gcloud auth application-default login'
Write-Host '  node scripts/set-moderator.js FIREBASE_AUTH_UID'

if ($FirebaseAuthUid -ne '') {
    Write-Host "Granting moderator access to UID: $FirebaseAuthUid"
    Set-Location $functionsDir
    gcloud auth application-default login
    node scripts/set-moderator.js $FirebaseAuthUid
    Set-Location $repoRoot
}

Write-Host ''
Write-Host 'Done. Open http://localhost:' + $LocalPort + ' in a browser.'
