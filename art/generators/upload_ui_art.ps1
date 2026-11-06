param(
    [string]$OutFile = "art/ui/uploaded-ui.json"
)

$key = [Environment]::GetEnvironmentVariable("ROBLOX_OPENCLOUD_KEY", "User")
$creator = [Environment]::GetEnvironmentVariable("ROBLOX_CREATOR_USER_ID", "User")
$headers = @{ "x-api-key" = $key }

$files = @()
$files += Get-ChildItem "art/ui/cards/*.png" | ForEach-Object { @{ stem = $_.BaseName; path = $_.FullName; kind = "ui-card" } }
$files += Get-ChildItem "art/ui/perks/*.png" | ForEach-Object { @{ stem = $_.BaseName; path = $_.FullName; kind = "ui-perk" } }

$uploaded = @{}
if (Test-Path $OutFile) {
    $raw = Get-Content $OutFile -Raw | ConvertFrom-Json
    foreach ($property in $raw.PSObject.Properties) { $uploaded[$property.Name] = $property.Value }
}

function Wait-Asset([string]$path) {
    for ($i = 0; $i -lt 40; $i++) {
        Start-Sleep -Seconds 2
        try {
            $state = Invoke-RestMethod -Method Get -Uri "https://apis.roblox.com/assets/v1/$path" -Headers $headers
        } catch {
            continue
        }
        if ($state.done -eq $true) {
            return $state.response.assetId
        }
    }
    return $null
}

$total = $files.Count
$index = 0
foreach ($file in $files) {
    $index += 1
    if ($uploaded.ContainsKey($file.stem)) {
        Write-Output "[$index/$total] $($file.stem) ya subido: $($uploaded[$file.stem])"
        continue
    }
    $request = @{
        assetType       = "Image"
        displayName     = "FlipTheTable $($file.kind) $($file.stem)"
        description     = "Flip the Table, ilustracion procedural. Generada por art/ui/$($file.kind.Replace('ui-',''))/."
        creationContext = @{ creator = @{ userId = $creator } }
    } | ConvertTo-Json -Depth 6 -Compress
    try {
        $created = Invoke-RestMethod -Method Post -Uri "https://apis.roblox.com/assets/v1/assets" -Headers $headers -Form @{ request = $request; fileContent = Get-Item $file.path }
        $assetId = Wait-Asset $created.path
        if ($assetId -eq $null) {
            Write-Output "[$index/$total] $($file.stem) TIMEOUT ($($created.path))"
            continue
        }
        $uploaded[$file.stem] = "$assetId"
        Write-Output "[$index/$total] $($file.stem) -> $assetId"
        $uploaded | ConvertTo-Json | Set-Content -Path $OutFile -Encoding utf8
    } catch {
        Write-Output "[$index/$total] $($file.stem) ERROR: $($_.Exception.Message)"
        $_.ErrorDetails.Message
    }
}

$uploaded | ConvertTo-Json | Set-Content -Path $OutFile -Encoding utf8
Write-Output "TOTAL $($uploaded.Count) de $total"
