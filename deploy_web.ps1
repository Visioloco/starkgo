# 🚀 deploy_web.ps1 — Compila la app para WEB y la publica en Firebase Hosting
#
# Uso:
#   .\deploy_web.ps1                 → compila y publica SOLO la web
#   .\deploy_web.ps1 -ConReglas      → además sube las reglas de Firestore
#   .\deploy_web.ps1 -SoloBuild      → sólo compila (no publica)
#
# Requisito: estar logueado en Firebase con la cuenta DUEÑA del proyecto.
#   firebase login:list      (ver con qué cuenta estás)
#   firebase login:add       (agregar/entrar con la cuenta dueña)

param(
  [string]$Project = 'starkgo-3671b',
  [switch]$SoloBuild,
  [switch]$ConReglas
)

$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $MyInvocation.MyCommand.Definition

Write-Host ''
Write-Host '1) Compilando la app para web (release)...' -ForegroundColor Cyan
Push-Location (Join-Path $raiz 'stark_go')
flutter build web --release
$buildOk = ($LASTEXITCODE -eq 0)
Pop-Location

if (-not $buildOk) {
  Write-Host '❌ Falló el build web. Revisá el mensaje de arriba.' -ForegroundColor Red
  exit 1
}

if ($SoloBuild) {
  Write-Host '✅ Build listo en: stark_go\build\web' -ForegroundColor Green
  exit 0
}

$target = if ($ConReglas) { 'hosting,firestore:rules' } else { 'hosting' }

Write-Host ''
Write-Host "2) Publicando ($target) en el proyecto '$Project'..." -ForegroundColor Cyan
Push-Location $raiz
firebase deploy --only $target --project $Project
$deployOk = ($LASTEXITCODE -eq 0)
Pop-Location

if (-not $deployOk) {
  Write-Host ''
  Write-Host '❌ El deploy falló. Si dice "Failed to get Firebase project":' -ForegroundColor Yellow
  Write-Host "     firebase login:add            (entrá con la cuenta dueña de $Project)" -ForegroundColor Yellow
  Write-Host "     firebase use $Project" -ForegroundColor Yellow
  Write-Host '   Después volvé a correr este script.' -ForegroundColor Yellow
  exit 1
}

Write-Host ''
Write-Host '✅ Listo. La web queda en:' -ForegroundColor Green
Write-Host "   https://$Project.web.app" -ForegroundColor Green
Write-Host "   https://$Project.firebaseapp.com" -ForegroundColor Green
if (-not $ConReglas) {
  Write-Host ''
  Write-Host 'ℹ️  Si cambiaste reglas de Firestore, corré:  .\deploy_web.ps1 -ConReglas' -ForegroundColor DarkGray
}
