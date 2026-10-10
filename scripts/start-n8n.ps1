$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Load-ProjectEnv.ps1')

if (-not (Get-Command n8n -ErrorAction SilentlyContinue)) {
    throw 'No encuentro el comando n8n. Comprueba la instalación de n8n y pnpm.'
}

Set-Location -LiteralPath $env:PROJECT_DIR
Write-Host 'Iniciando n8n en http://localhost:5678'
Write-Host 'Execute Command habilitado; acceso a archivos limitado a la carpeta videos.'
& n8n
