$ErrorActionPreference = 'Stop'

$script:ProjectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$envFile = Join-Path $script:ProjectRoot '.env'

if (Test-Path -LiteralPath $envFile -PathType Leaf) {
    foreach ($line in Get-Content -LiteralPath $envFile -Encoding UTF8) {
        if ([string]::IsNullOrWhiteSpace($line) -or $line.TrimStart().StartsWith('#')) {
            continue
        }

        $separator = $line.IndexOf('=')
        if ($separator -lt 1) {
            continue
        }

        $name = $line.Substring(0, $separator).Trim()
        $value = $line.Substring($separator + 1).Trim()
        if ($value.Length -ge 2 -and (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'")))) {
            $value = $value.Substring(1, $value.Length - 2)
        }
        [System.Environment]::SetEnvironmentVariable($name, $value, 'Process')
    }
}

function Resolve-ProjectPath {
    param(
        [string]$Value,
        [string]$DefaultValue,
        [string]$BasePath = $script:ProjectRoot
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        $Value = $DefaultValue
    }
    if (-not [System.IO.Path]::IsPathRooted($Value)) {
        $Value = Join-Path $BasePath $Value
    }
    return [System.IO.Path]::GetFullPath($Value)
}

$env:PROJECT_DIR = $script:ProjectRoot
$env:COMFYUI_DIR = Resolve-ProjectPath -Value $env:COMFYUI_DIR -DefaultValue '..\__RESOURCES\ComfyUI_windows_portable'
$defaultComfyOutput = Join-Path $env:COMFYUI_DIR 'ComfyUI\output'
$env:COMFYUI_OUTPUT_DIR = Resolve-ProjectPath -Value $env:COMFYUI_OUTPUT_DIR -DefaultValue $defaultComfyOutput
$env:VIDEO_OUTPUT_DIR = Resolve-ProjectPath -Value $env:VIDEO_OUTPUT_DIR -DefaultValue 'videos'
$env:AUDIO_FILE = Resolve-ProjectPath -Value $env:AUDIO_FILE -DefaultValue 'assets\audio\Dorian_concept.mp3'

if (-not [string]::IsNullOrWhiteSpace($env:FFMPEG_EXE)) {
    $env:FFMPEG_EXE = Resolve-ProjectPath -Value $env:FFMPEG_EXE -DefaultValue ''
}

if ([string]::IsNullOrWhiteSpace($env:NODES_EXCLUDE)) {
    $env:NODES_EXCLUDE = '["n8n-nodes-base.localFileTrigger"]'
}
$env:N8N_RESTRICT_FILE_ACCESS_TO = $env:VIDEO_OUTPUT_DIR
