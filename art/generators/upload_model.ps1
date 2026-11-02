# Sube un FBX como Model a Roblox por Open Cloud y espera a que la operación termine.
#
# Uso:
#   $env:ROBLOX_OPENCLOUD_KEY = "<clave>"     (o pasa -KeyFile)
#   pwsh -File art/generators/upload_model.ps1 -Path art/blender/facade/facade_wall.fbx -Name facade-wall
#
# Tres cosas que cuestan una tarde si no se saben:
#
#   1. La clave va en la cabecera `x-api-key`. Con `Authorization: Bearer` responde 401.
#   2. `assetType: Model` NO acepta `application/octet-stream`: hay que mandar el FBX con
#      `content-type: model/fbx`, o devuelve 400 "not supported yet".
#   3. El campo `request` tiene que ser su propia parte multipart con `application/json`.
#      El `-Form` de PowerShell lo manda como texto plano y la API lo rechaza.
#
# El modelo llega SIN texturas: Open Cloud no genera SurfaceAppearance desde el FBX. Los
# materiales se aplican en Studio con MaterialVariant (ver art/PIPELINE.md).

param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Name,
    [string]$Description = "",
    [string]$ContentType = "model/fbx",
    [string]$AssetType = "Model",
    [string]$KeyFile = "",
    [int]$TimeoutSeconds = 180
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Net.Http

$key = $env:ROBLOX_OPENCLOUD_KEY
if (-not $key -and $KeyFile -and (Test-Path $KeyFile)) {
    $key = (Get-Content $KeyFile -Raw).Trim()
}
if (-not $key) {
    throw "Falta la clave. Define ROBLOX_OPENCLOUD_KEY o pasa -KeyFile."
}
if (-not $env:ROBLOX_CREATOR_USER_ID) {
    throw "Falta ROBLOX_CREATOR_USER_ID: el creador al que pertenece el asset."
}
if (-not (Test-Path $Path)) {
    throw "No existe el archivo $Path"
}

$request = @{
    assetType       = $AssetType
    displayName     = $Name
    description     = $Description
    creationContext = @{ creator = @{ userId = "$env:ROBLOX_CREATOR_USER_ID" } }
} | ConvertTo-Json -Depth 6 -Compress

$client = [System.Net.Http.HttpClient]::new()
$client.Timeout = [TimeSpan]::FromSeconds($TimeoutSeconds)
$client.DefaultRequestHeaders.Add("x-api-key", $key)

$multipart = [System.Net.Http.MultipartFormDataContent]::new()
$jsonPart = [System.Net.Http.StringContent]::new($request, [System.Text.Encoding]::UTF8)
$jsonPart.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse("application/json")
$multipart.Add($jsonPart, "request")

$stream = [System.IO.File]::OpenRead($Path)
$filePart = [System.Net.Http.StreamContent]::new($stream)
$filePart.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse($ContentType)
$multipart.Add($filePart, "fileContent", [System.IO.Path]::GetFileName($Path))

try {
    $response = $client.PostAsync("https://apis.roblox.com/assets/v1/assets", $multipart).Result
    $body = $response.Content.ReadAsStringAsync().Result
} finally {
    $stream.Dispose()
}

if (-not $response.IsSuccessStatusCode) {
    Write-Output "ERROR $([int]$response.StatusCode) $($response.StatusCode)"
    Write-Output $body
    exit 1
}

$operation = $body | ConvertFrom-Json
Write-Output "operacion: $($operation.path)"

for ($attempt = 0; $attempt -lt 60; $attempt++) {
    Start-Sleep -Seconds 3
    $state = ($client.GetStringAsync("https://apis.roblox.com/assets/v1/$($operation.path)").Result) | ConvertFrom-Json
    if ($state.done) {
        Write-Output "assetId: $($state.response.assetId)"
        Write-Output "estado:  $($state.response.state) / moderacion: $($state.response.moderationResult.moderationState)"
        exit 0
    }
}

Write-Output "TIMEOUT: la operación no terminó en $TimeoutSeconds segundos"
exit 2
