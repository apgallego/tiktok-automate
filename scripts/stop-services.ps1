param(
    [switch]$KeepOllama
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Load-ProjectEnv.ps1')

$comfyPort = ([uri]$env:COMFYUI_URL).Port
$targets = @(
    [pscustomobject]@{
        Service = 'n8n'
        Port = 5678
        ProcessNamePattern = '^(node|n8n)(\.exe)?$'
        CommandLinePattern = '(?i)n8n'
    },
    [pscustomobject]@{
        Service = 'ComfyUI'
        Port = $comfyPort
        ProcessNamePattern = '^(python|python3)(\.exe)?$'
        CommandLinePattern = '(?i)ComfyUI[\\/]main\.py'
    }
)

if (-not $KeepOllama) {
    $targets += [pscustomobject]@{
        Service = 'Ollama'
        Port = 11434
        ProcessNamePattern = '(?i)^ollama(\.exe)?$'
        CommandLinePattern = '(?i)ollama'
    }
}

$stopped = 0
foreach ($target in $targets) {
    $listeners = @(Get-NetTCPConnection -LocalPort $target.Port -State Listen -ErrorAction SilentlyContinue)
    if ($listeners.Count -eq 0) {
        Write-Host "$($target.Service): no está activo en el puerto $($target.Port)."
        continue
    }

    foreach ($listenerPid in @($listeners | Select-Object -ExpandProperty OwningProcess -Unique)) {
        $process = Get-CimInstance Win32_Process -Filter "ProcessId = $listenerPid" -ErrorAction SilentlyContinue
        if (-not $process) {
            Write-Warning "No pude identificar el proceso $listenerPid que escucha en el puerto $($target.Port)."
            continue
        }

        $matchesName = $process.Name -match $target.ProcessNamePattern
        $matchesCommand = [string]::IsNullOrWhiteSpace($target.CommandLinePattern) -or $process.CommandLine -match $target.CommandLinePattern
        if (-not ($matchesName -and $matchesCommand)) {
            Write-Warning "$($target.Service): el puerto $($target.Port) lo usa '$($process.Name)' (PID $listenerPid), que no parece pertenecer a este servicio. No lo detuve."
            continue
        }

        try {
            Stop-Process -Id $listenerPid -ErrorAction Stop
            Write-Host "$($target.Service): detenido (PID $listenerPid, puerto $($target.Port))."
            $stopped++
        }
        catch {
            Write-Warning "No pude detener $($target.Service) (PID $listenerPid): $($_.Exception.Message)"
        }
    }
}

if ($stopped -eq 0) {
    Write-Host 'No había procesos del proyecto que detener.'
}
else {
    Write-Host 'Servicios detenidos. Ollama se conserva si ejecutaste el script con -KeepOllama.'
}
