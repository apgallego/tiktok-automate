param(
    [Parameter(Mandatory = $true)]
    [string]$PromptBase64
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Load-ProjectEnv.ps1')

$comfyUrl = if ([string]::IsNullOrWhiteSpace($env:COMFYUI_URL)) { 'http://127.0.0.1:8188' } else { $env:COMFYUI_URL.TrimEnd('/') }
$workflowPath = Join-Path $env:PROJECT_DIR 'workflows\workdlow-dfantasy.json'
$promptNodeId = '73'
$saveNodeId = '78'

if (-not (Test-Path -LiteralPath $workflowPath -PathType Leaf)) {
    throw "No encuentro el workflow API de ComfyUI: $workflowPath"
}

try {
    $prompt = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($PromptBase64)).Trim()
}
catch {
    throw 'El prompt recibido desde n8n no tiene un formato Base64 válido.'
}

if ([string]::IsNullOrWhiteSpace($prompt)) {
    throw 'Ollama devolvió un prompt vacío.'
}
if ($prompt.Length -gt 4000) {
    throw "El prompt de Ollama supera los 4000 caracteres ($($prompt.Length))."
}

$workflow = Get-Content -LiteralPath $workflowPath -Raw -Encoding UTF8 | ConvertFrom-Json
$positiveNode = $workflow.PSObject.Properties[$promptNodeId]
if (-not $positiveNode -or $positiveNode.Value.class_type -ne 'CLIPTextEncode') {
    throw "No encuentro el nodo CLIPTextEncode positivo $promptNodeId en el JSON API."
}
$saveNode = $workflow.PSObject.Properties[$saveNodeId]
if (-not $saveNode -or $saveNode.Value.class_type -ne 'SaveImage') {
    throw "No encuentro el nodo SaveImage $saveNodeId en el JSON API."
}

$positiveNode.Value.inputs.text = $prompt
$seedNode = $workflow.PSObject.Properties['76']
if ($seedNode -and $seedNode.Value.inputs.PSObject.Properties['seed']) {
    $seedNode.Value.inputs.seed = Get-Random -Minimum 1 -Maximum 2147483647
}

$requestBody = @{
    prompt = $workflow
    client_id = [guid]::NewGuid().ToString()
} | ConvertTo-Json -Depth 100 -Compress
$requestBytes = [System.Text.Encoding]::UTF8.GetBytes($requestBody)

try {
    $queued = Invoke-RestMethod -Method Post -Uri "$comfyUrl/prompt" -ContentType 'application/json; charset=utf-8' -Body $requestBytes -TimeoutSec 60
}
catch {
    throw "No se pudo enviar el workflow a ComfyUI en $comfyUrl. Comprueba que ComfyUI esté iniciado. Detalle: $($_.Exception.Message)"
}
if ([string]::IsNullOrWhiteSpace($queued.prompt_id)) {
    throw "ComfyUI no devolvió prompt_id. Respuesta: $($queued | ConvertTo-Json -Depth 10 -Compress)"
}

$promptId = [string]$queued.prompt_id
$historyUrl = "$comfyUrl/history/$promptId"
$deadline = (Get-Date).AddMinutes(20)
$historyEntry = $null
while ((Get-Date) -lt $deadline) {
    Start-Sleep -Seconds 2
    try {
        $history = Invoke-RestMethod -Method Get -Uri $historyUrl -TimeoutSec 30
    }
    catch {
        continue
    }
    $entryProperty = $history.PSObject.Properties[$promptId]
    if ($entryProperty) {
        $historyEntry = $entryProperty.Value
        break
    }
}

if (-not $historyEntry) {
    throw "ComfyUI no terminó la generación dentro de 20 minutos. prompt_id=$promptId"
}
if ($historyEntry.status.status_str -eq 'error') {
    throw "ComfyUI terminó con error. prompt_id=$promptId"
}

$outputProperty = $historyEntry.outputs.PSObject.Properties[$saveNodeId]
if (-not $outputProperty -or -not $outputProperty.Value.images -or $outputProperty.Value.images.Count -lt 1) {
    throw "La generación terminó, pero el nodo Save Image $saveNodeId no devolvió ninguna imagen. prompt_id=$promptId"
}

$generatedImage = $outputProperty.Value.images[0]
$imagePath = $env:COMFYUI_OUTPUT_DIR
if (-not [string]::IsNullOrWhiteSpace($generatedImage.subfolder)) {
    $imagePath = Join-Path $imagePath $generatedImage.subfolder
}
$imagePath = Join-Path $imagePath $generatedImage.filename
if (-not (Test-Path -LiteralPath $imagePath -PathType Leaf)) {
    throw "ComfyUI informó una imagen que no encuentro en disco: $imagePath"
}

& (Join-Path $PSScriptRoot 'crear-video.ps1') -InputImage $imagePath
