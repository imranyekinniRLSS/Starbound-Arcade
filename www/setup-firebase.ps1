param(
    [string]$ProjectId = 'sign-up-login-82aee',
    [switch]$SkipDeploy
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $repoRoot

Write-Host 'Installing Firebase CLI...'
npm install --global firebase-tools

Write-Host "Signing in to Firebase for project: $ProjectId"
firebase login

if (-not $SkipDeploy) {
    Write-Host 'Deploying Firestore rules, indexes, and Cloud Functions...'
    firebase deploy --project $ProjectId --only firestore:rules,firestore:indexes,functions
}

Write-Host 'Firebase setup complete.'
Write-Host 'Next step: run .\start-local-dev.ps1 or open community.html through HTTP.'
