param(
    [string]$InputImage = "",
    [string]$AudioFile = ""
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot 'Load-ProjectEnv.ps1')

$comfyOutput = $env:COMFYUI_OUTPUT_DIR
$videoOutput = $env:VIDEO_OUTPUT_DIR
if ([string]::IsNullOrWhiteSpace($AudioFile)) {
    $AudioFile = $env:AUDIO_FILE
}

$ffmpeg = $env:FFMPEG_EXE
if ($ffmpeg -and -not (Test-Path -LiteralPath $ffmpeg -PathType Leaf)) {
    throw "No encuentro FFMPEG_EXE: $ffmpeg"
}

$ffmpegPattern = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages\Gyan.FFmpeg*\*\bin\ffmpeg.exe"
if (-not $ffmpeg) {
    $ffmpeg = Get-ChildItem -Path $ffmpegPattern -File -ErrorAction SilentlyContinue |
        Select-Object -First 1 -ExpandProperty FullName
}

if (-not $ffmpeg) {
    throw "No encuentro ffmpeg.exe en el paquete de WinGet de Gyan."
}

if ([string]::IsNullOrWhiteSpace($InputImage)) {
    $image = Get-ChildItem -LiteralPath $comfyOutput -Filter "*.png" -File |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    if (-not $image) {
        throw "No hay imágenes PNG en $comfyOutput"
    }
    $InputImage = $image.FullName
}

if (-not (Test-Path -LiteralPath $InputImage -PathType Leaf)) {
    throw "No existe la imagen: $InputImage"
}

if (-not (Test-Path -LiteralPath $AudioFile -PathType Leaf)) {
    throw "No existe la pista de audio: $AudioFile"
}

New-Item -ItemType Directory -Path $videoOutput -Force | Out-Null
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$outputFile = Join-Path $videoOutput "paisaje-$timestamp.mp4"

$filter = "scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,zoompan=z='min(zoom+0.00025,1.10)':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=450:s=1080x1920:fps=30,format=yuv420p"

& $ffmpeg -y -loop 1 -framerate 30 -i $InputImage -i $AudioFile -vf $filter -map 0:v:0 -map 1:a:0 -frames:v 450 -t 15 -c:v libx264 -preset veryfast -crf 24 -c:a aac -b:a 192k -af "afade=t=out:st=14:d=1" -movflags +faststart $outputFile
if ($LASTEXITCODE -ne 0) {
    throw "FFmpeg terminó con código $LASTEXITCODE"
}

Write-Output "VIDEO_CREADO=$outputFile"
