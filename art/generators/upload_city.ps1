# Sube en lote los FBX de un barrio a Roblox por Open Cloud y guarda el mapa archivo -> assetId.
#
# Es el mismo camino que `upload_model.ps1` (ver art/PIPELINE.md §7), pero para una carpeta entera:
# los barrios exportan entre 20 y 40 mallas y subirlas de una en una a mano no se sostiene.
#
# Uso:
#   pwsh -File art/generators/upload_city.ps1 -Prefix centro
#   pwsh -File art/generators/upload_city.ps1 -Prefix puerto -Folder art/blender/city
#
# La clave se lee de ROBLOX_OPENCLOUD_KEY (entorno o ámbito de usuario de Windows) o de -KeyFile.
# Lo ya subido no se repite: el mapa se lee y se completa, así que se puede relanzar sin gastar cuota.

param(
    [Parameter(Mandatory = $true)][string]$Prefix,
    [string]$Folder = "art/blender/city",
    [string]$OutFile = "art/blender/city/uploaded.json",
    [string]$KeyFile = "",
    [int]$TimeoutSeconds = 240
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Net.Http

$key = $env:ROBLOX_OPENCLOUD_KEY
if (-not $key) {
    $key = [Environment]::GetEnvironmentVariable("ROBLOX_OPENCLOUD_KEY", "User")
}
if (-not $key -and $KeyFile -and (Test-Path $KeyFile)) {
    $key = (Get-Content $KeyFile -Raw).Trim()
}
if (-not $key) {
    throw "Falta la clave. Define ROBLOX_OPENCLOUD_KEY o pasa -KeyFile."
}

$creator = $env:ROBLOX_CREATOR_USER_ID
if (-not $creator) {
    $creator = [Environment]::GetEnvironmentVariable("ROBLOX_CREATOR_USER_ID", "User")
}
if (-not $creator) {
    throw "Falta ROBLOX_CREATOR_USER_ID: el creador al que pertenecen los assets."
}

$repo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$folderPath = if ([System.IO.Path]::IsPathRooted($Folder)) { $Folder } else { Join-Path $repo $Folder }
$outPath = if ([System.IO.Path]::IsPathRooted($OutFile)) { $OutFile } else { Join-Path $repo $OutFile }

$uploaded = @{}
if (Test-Path $outPath) {
    (Get-Content $outPath -Raw | ConvertFrom-Json).PSObject.Properties | ForEach-Object {
        $uploaded[$_.Name] = $_.Value
    }
}

function Upload-Model {
    param([string]$Path, [string]$Name)

    $request = @{
        assetType       = "Model"
        displayName     = $Name
        description     = ""
        creationContext = @{ creator = @{ userId = "$creator" } }
    } | ConvertTo-Json -Depth 6 -Compress

    $client = [System.Net.Http.HttpClient]::new()
    $client.Timeout = [TimeSpan]::FromSeconds($TimeoutSeconds)
    $client.DefaultRequestHeaders.Add("x-api-key", $key) | Out-Null

    $multipart = [System.Net.Http.MultipartFormDataContent]::new()
    $jsonPart = [System.Net.Http.StringContent]::new($request, [System.Text.Encoding]::UTF8)
    $jsonPart.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse("application/json")
    $multipart.Add($jsonPart, "request")

    $stream = [System.IO.File]::OpenRead($Path)
    $filePart = [System.Net.Http.StreamContent]::new($stream)
    $filePart.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse("model/fbx")
    $multipart.Add($filePart, "fileContent", [System.IO.Path]::GetFileName($Path))

    try {
        $response = $client.PostAsync("https://apis.roblox.com/assets/v1/assets", $multipart).Result
        $body = $response.Content.ReadAsStringAsync().Result
    }
    finally {
        $stream.Dispose()
    }

    if (-not $response.IsSuccessStatusCode) {
        throw "HTTP $([int]$response.StatusCode): $body"
    }

    $operation = $body | ConvertFrom-Json
    for ($attempt = 0; $attempt -lt 80; $attempt++) {
        Start-Sleep -Seconds 2
        $state = ($client.GetStringAsync("https://apis.roblox.com/assets/v1/$($operation.path)").Result) | ConvertFrom-Json
        if ($state.done) {
            if (-not $state.response.assetId) {
                throw "la operación terminó sin assetId: $($state | ConvertTo-Json -Depth 5 -Compress)"
            }
            return "rbxassetid://$($state.response.assetId)"
        }
    }
    throw "la operación no terminó en $TimeoutSeconds segundos"
}

$files = Get-ChildItem -Path $folderPath -Filter "$Prefix*.fbx" | Where-Object { $_.Name -notmatch "_LOD1" } | Sort-Object Name
if (-not $files) {
    throw "No hay FBX con prefijo '$Prefix' en $folderPath"
}

$done = 0
foreach ($file in $files) {
    $key0 = $file.Name
    if ($uploaded.ContainsKey($key0)) {
        Write-Output "ya subido: $key0 -> $($uploaded[$key0])"
        continue
    }
    # El nombre visible del asset es el del FBX sin extensión: el mismo texto que el id del manifiesto.
    $displayName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name) -replace "_", "-"
    $id = $null
    for ($try = 1; $try -le 3; $try++) {
        try {
            $id = Upload-Model -Path $file.FullName -Name $displayName
            break
        }
        catch {
            Write-Output "fallo ($try/3) $key0 : $_"
            Start-Sleep -Seconds 4
        }
    }
    if ($null -eq $id) {
        Write-Output "ERROR $key0 no se pudo subir"
        continue
    }
    $uploaded[$key0] = $id
    $done++
    Write-Output "subido: $key0 -> $id ($done/$($files.Count))"
    $uploaded | ConvertTo-Json | Set-Content -Path $outPath -Encoding UTF8
    Start-Sleep -Milliseconds 400
}

$uploaded | ConvertTo-Json | Set-Content -Path $outPath -Encoding UTF8
Write-Output "TOTAL $($uploaded.Count) assets en $outPath"
