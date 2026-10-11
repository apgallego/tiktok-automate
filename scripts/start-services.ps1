param(
    [int]$StartupTimeoutSeconds = 180
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Load-ProjectEnv.ps1')

$projectDir = $env:PROJECT_DIR
$logDir = Join-Path $projectDir 'logs'
New-Item -ItemType Directory -Path $logDir -Force | Out-Null

$services = @(
    [pscustomobject]@{
        Name = 'Ollama'
        Url = 'http://127.0.0.1:11434/api/tags'
        StartFile = $null
        Arguments = @()
        Timeout = 60
    },
    [pscustomobject]@{
        Name = 'ComfyUI'
        Url = "$($env:COMFYUI_URL)/system_stats"
        StartFile = Join-Path $PSScriptRoot 'start-comfyui.ps1'
        Arguments = @()
        Timeout = $StartupTimeoutSeconds
    },
    [pscustomobject]@{
        Name = 'n8n'
        Url = 'http://127.0.0.1:5678/healthz'
        StartFile = Join-Path $PSScriptRoot 'start-n8n.ps1'
        Arguments = @()
        Timeout = 90
    }
)

$powershellExe = (Get-Process -Id $PID).Path

foreach ($service in $services) {
    $ready = $false
    try {
        $null = Invoke-RestMethod -Uri $service.Url -TimeoutSec 3
        $ready = $true
        Write-Host "$($service.Name): ya está activo en $($service.Url)."
    }
    catch {
        # El endpoint no responde: intenta arrancar el servicio.
    }

    if (-not $ready) {
        if ($service.Name -eq 'Ollama') {
            $ollamaCommand = Get-Command 'ollama.exe' -CommandType Application -ErrorAction SilentlyContinue
            if (-not $ollamaCommand) {
                $ollamaCommand = Get-Command 'ollama' -CommandType Application -ErrorAction SilentlyContinue
            }
            if (-not $ollamaCommand) {
                throw 'No encuentro ollama.exe en PATH. Instala Ollama o inicia su aplicación y vuelve a ejecutar este script.'
            }
            $startFile = $ollamaCommand.Source
            $arguments = @('serve')
        }
        else {
            $startFile = $powershellExe
            $arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$($service.StartFile)`"")
        }

        $safeName = $service.Name.ToLowerInvariant()
        $stdoutPath = Join-Path $logDir "$safeName-start.log"
        $stderrPath = Join-Path $logDir "$safeName-start.err.log"
        Write-Host "Iniciando $($service.Name); registros: $stdoutPath"
        Start-Process -FilePath $startFile `
            -ArgumentList $arguments `
            -WorkingDirectory $projectDir `
            -WindowStyle Hidden `
            -RedirectStandardOutput $stdoutPath `
            -RedirectStandardError $stderrPath | Out-Null
    }

    $deadline = (Get-Date).AddSeconds($service.Timeout)
    while (-not $ready -and (Get-Date) -lt $deadline) {
        Start-Sleep -Seconds 2
        try {
            $null = Invoke-RestMethod -Uri $service.Url -TimeoutSec 3
            $ready = $true
        }
        catch {
            # Sigue esperando hasta el límite del servicio.
        }
    }

    if (-not $ready) {
        throw "$($service.Name) no respondió en $($service.Timeout) segundos. Revisa $stderrPath y el registro de salida correspondiente en $logDir."
    }
    Write-Host "$($service.Name): listo."
}

Write-Host 'Servicios locales listos. n8n está en http://localhost:5678.'
