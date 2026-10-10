$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Load-ProjectEnv.ps1')

$launchFile = Join-Path $env:COMFYUI_DIR 'run_nvidia_gpu.bat'
if (-not (Test-Path -LiteralPath $launchFile -PathType Leaf)) {
    throw "No encuentro run_nvidia_gpu.bat en COMFYUI_DIR: $($env:COMFYUI_DIR)"
}

& $launchFile
