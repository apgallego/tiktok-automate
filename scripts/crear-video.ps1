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

$image = Get-Item -LiteralPath $InputImage
$imageSignature = [ordered]@{
    path = $image.FullName
    lastWriteTimeUtcTicks = $image.LastWriteTimeUtc.Ticks
    length = $image.Length
}
$imageMarker = Join-Path $videoOutput ".last-image-used.json"
if (-not $PSBoundParameters.ContainsKey('InputImage') -and (Test-Path -LiteralPath $imageMarker -PathType Leaf)) {
    $previousImage = Get-Content -LiteralPath $imageMarker -Raw | ConvertFrom-Json
    if ($previousImage.path -eq $imageSignature.path -and
        [long]$previousImage.lastWriteTimeUtcTicks -eq $imageSignature.lastWriteTimeUtcTicks -and
        [long]$previousImage.length -eq $imageSignature.length) {
        throw "El PNG más reciente ya se usó para crear un vídeo: $($image.FullName). En ComfyUI cambia el prompt positivo, pulsa Queue Prompt y espera a que termine una generación nueva antes de ejecutar este nodo."
    }
}

if (-not (Test-Path -LiteralPath $AudioFile -PathType Leaf)) {
    throw "No existe la pista de audio: $AudioFile"
}

New-Item -ItemType Directory -Path $videoOutput -Force | Out-Null
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$outputFile = Join-Path $videoOutput "paisaje-$timestamp.mp4"

$filter = "scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,zoompan=z='min(1+0.0015*on,1.36)':x='(iw-iw/zoom)*(0.20+0.50*on/239+0.08*sin(2*PI*on/239))':y='(ih-ih/zoom)*(0.18+0.44*on/239+0.05*sin(2*PI*on/239+PI/2))':d=240:s=1080x1920:fps=30,fade=t=out:st=7:d=1,format=yuv420p"

& $ffmpeg -y -loop 1 -framerate 30 -i $InputImage -i $AudioFile -vf $filter -map 0:v:0 -map 1:a:0 -frames:v 240 -t 8 -c:v libx264 -preset veryfast -crf 24 -c:a aac -b:a 192k -af "afade=t=out:st=7:d=1" -movflags +faststart $outputFile
if ($LASTEXITCODE -ne 0) {
    throw "FFmpeg terminó con código $LASTEXITCODE"
}

$imageSignature | ConvertTo-Json | Set-Content -LiteralPath $imageMarker -Encoding UTF8
Write-Output "VIDEO_CREADO=$outputFile"
